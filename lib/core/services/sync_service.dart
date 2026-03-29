import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_storage_service.dart';
import '../../features/sales/data/sales_repository.dart';
import '../../features/reports/data/movement_repository.dart';

class SyncService {
  final LocalStorageService _localStorage;
  final SalesRepository _salesRepo;
  final MovementRepository _movementRepo;
  
  // SOLUCIÓN: Callback para avisar a Riverpod
  final void Function()? onSyncComplete;

  bool _isSyncing = false;
  // SOLUCIÓN: Manejo de suscripción para evitar fuga de memoria
  StreamSubscription? _connectivitySubscription;

  SyncService({
    required LocalStorageService localStorage,
    required SalesRepository salesRepo,
    required MovementRepository movementRepo,
    this.onSyncComplete,
  })  : _localStorage = localStorage,
        _salesRepo = salesRepo,
        _movementRepo = movementRepo;

  void start() {
    _connectivitySubscription?.cancel();
    
    // Escuchar cambios de red de forma segura
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_isSyncing) {
        debugPrint('[SyncService] Conexión restaurada. Sincronizando...');
        _syncPending();
      }
    });

    // Intento inicial
    _syncPending();
  }

  // SOLUCIÓN: Limpieza de recursos
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('[SyncService] Suscripción de conectividad cancelada.');
  }

  Future<void> _syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _syncInventory();
      await _syncSales();
      await _syncMovements();
      
      // SOLUCIÓN: Ejecutar callback tras éxito
      onSyncComplete?.call();
      debugPrint('[SyncService] Cola de sincronización procesada.');
    } catch (e) {
      debugPrint('[SyncService] Error en proceso de sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncInventory() async {
    final pending = await _localStorage.getPendingInventoryUpdates();
    for (final update in pending) {
      try {
        await _salesRepo.productRepository.updateStock(
          update['productId'].toString(),
          int.parse(update['newStock'].toString()),
          isSyncing: true,
        );
        await _localStorage.removePendingInventoryUpdate(update['queue_key']);
      } catch (_) { break; }
    }
  }

  Future<void> _syncSales() async {
    final pending = await _localStorage.getPendingSales();
    for (final saleJson in List.from(pending)) {
      try {
        await _salesRepo.resyncSale(saleJson);
        await _localStorage.removePendingSale(saleJson['id_venta'].toString());
      } catch (_) { break; }
    }
  }

  Future<void> _syncMovements() async {
    final pending = await _localStorage.getPendingMovements();
    for (final mov in List.from(pending)) {
      try {
        await _movementRepo.resyncMovement(mov);
        await _localStorage.removePendingMovement(mov['id'].toString());
      } catch (_) { break; }
    }
  }

  Future<void> forceSync() => _syncPending();
}

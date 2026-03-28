import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import '../services/local_storage_service.dart';
import '../../features/sales/data/sales_repository.dart';
import '../../features/reports/data/movement_repository.dart';

/// Servicio de sincronización en segundo plano.
///
/// Escucha cambios de conectividad y, cuando se detecta una conexión disponible,
/// intenta vaciar las colas de ventas y movimientos pendientes enviándolos
/// a la base de datos remota (FastAPI / Google Sheets).
class SyncService {
  final LocalStorageService _localStorage;
  final SalesRepository _salesRepo;
  final MovementRepository _movementRepo;

  bool _isSyncing = false;

  SyncService({
    required LocalStorageService localStorage,
    required SalesRepository salesRepo,
    required MovementRepository movementRepo,
  })  : _localStorage = localStorage,
        _salesRepo = salesRepo,
        _movementRepo = movementRepo;

  /// Inicia la escucha de conectividad. Llamar una sola vez desde main.dart.
  void start() {
    Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_isSyncing) {
        _syncPending();
      }
    });

    // Intentar sincronizar al arrancar (por si ya hay conexión)
    _syncPending();
  }

  Future<void> _syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // 1. Sincronizar actualizaciones de stock primero para asegurar integridad
      await _syncInventory();
      
      // 2. Sincronizar ventas y movimientos
      await _syncSales();
      await _syncMovements();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncInventory() async {
    final box = Hive.box('inventory_queue');
    if (box.isEmpty) return;

    final keys = box.keys.toList();
    debugPrint('[SyncService] Sincronizando ${keys.length} actualizaciones de stock pendientes...');

    for (final key in keys) {
      final action = box.get(key) as Map;
      try {
        await _salesRepo.productRepository.updateStock(
          action['productId'].toString(),
          int.tryParse(action['newStock'].toString()) ?? 0,
          isSyncing: true,
        );
        await box.delete(key);
        debugPrint('[SyncService] Stock sincronizado: ${action['productId']}');
      } catch (e) {
        debugPrint('[SyncService] Error sincronizando stock de ${action['productId']}: $e');
        // Detener el ciclo para evitar reintentos fallidos masivos
        break;
      }
    }
  }

  Future<void> _syncSales() async {
    final pendingSales = await _localStorage.getPendingSales();
    if (pendingSales.isEmpty) return;

    debugPrint('[SyncService] Sincronizando ${pendingSales.length} ventas pendientes...');

    for (final saleJson in List.from(pendingSales)) {
      try {
        await _salesRepo.resyncSale(saleJson);
        await _localStorage.removePendingSale(saleJson['id_venta'].toString());
        debugPrint('[SyncService] Venta sincronizada: ${saleJson['id_venta']}');
      } catch (e) {
        debugPrint('[SyncService] Fallo al sincronizar venta ${saleJson['id_venta']}: $e');
        // Dejar en cola para el próximo intento
        break;
      }
    }
  }

  Future<void> _syncMovements() async {
    final pendingMovements = await _localStorage.getPendingMovements();
    if (pendingMovements.isEmpty) return;

    debugPrint('[SyncService] Sincronizando ${pendingMovements.length} movimientos pendientes...');

    for (final movMap in List.from(pendingMovements)) {
      try {
        await _movementRepo.resyncMovement(movMap);
        await _localStorage.removePendingMovement(movMap['id'].toString());
        debugPrint('[SyncService] Movimiento sincronizado: ${movMap['id']}');
      } catch (e) {
        debugPrint('[SyncService] Fallo al sincronizar movimiento ${movMap['id']}: $e');
        break;
      }
    }
  }

  /// Fuerza una sincronización inmediata. Útil para botón "Reintentar" en UI.
  Future<void> forceSync() => _syncPending();
}

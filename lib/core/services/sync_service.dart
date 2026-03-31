import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/local_storage_service.dart';
import '../../features/sales/data/sales_repository.dart';
import '../../features/reports/data/movement_repository.dart';
import '../../features/inventory/domain/product.dart';


class SyncService {
  final LocalStorageService _localStorage;
  final SalesRepository _salesRepo;
  final MovementRepository _movementRepo;
  
  final void Function()? onSyncComplete;

  bool _isSyncing = false;
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
    
    // Escucha la red y revive la sincronización sin colapsar
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && !_isSyncing) {
        debugPrint('[SyncService] Conexión restaurada. Sincronizando...');
        _syncPending();
      }
    });

    _syncPending();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('[SyncService] Suscripción cancelada.');
  }

  Future<void> _syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _syncInventory();
      await _syncSales();
      await _syncMovements();
      await _syncPayments();
      
      onSyncComplete?.call();
      debugPrint('[SyncService] Cola procesada exitosamente.');
    } catch (e, stack) {
      debugPrint('[SyncService] Error general, reintentará luego: $e \n $stack');
      // SOLUCIÓN: Se eliminó el "rethrow" para no matar el hilo en segundo plano
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncInventory() async {
    final pending = await _localStorage.getPendingInventoryUpdates();
    final repo = _salesRepo.productRepository;

    for (final update in pending) {
      try {
        final type = update['type']?.toString();

        if (type == 'stock' || type == null) {
          // Retrocompatibilidad o actualización simple de stock
          await repo.updateStock(
            update['productId'].toString(),
            int.parse(update['newStock'].toString()),
            isSyncing: true,
          );
        } else if (type == 'add') {
          final product = Product.fromJson(Map<String, dynamic>.from(update['product']));
          await repo.addProduct(product, isSyncing: true);
        } else if (type == 'edit') {
          final product = Product.fromJson(Map<String, dynamic>.from(update['product']));
          await repo.updateProduct(product, isSyncing: true);
        } else if (type == 'delete') {
          await repo.deleteProduct(update['productId'].toString(), isSyncing: true);
        }

        await _localStorage.removePendingInventoryUpdate(update['queue_key']);
      } catch (e) {
        debugPrint('Fallo silencioso en sincronización de Inventario ($update): $e');
        break; 
      }
    }
  }


  Future<void> _syncSales() async {
    final pending = await _localStorage.getPendingSales();
    for (final saleJson in List.from(pending)) {
      try {
        await _salesRepo.resyncSale(saleJson);
        await _localStorage.removePendingSale(saleJson['id_venta'].toString());
      } catch (e) {
        debugPrint('Fallo silencioso en Ventas: $e');
        break; 
      }
    }
  }

  Future<void> _syncMovements() async {
    final pending = await _localStorage.getPendingMovements();
    for (final mov in List.from(pending)) {
      try {
        await _movementRepo.resyncMovement(mov);
        await _localStorage.removePendingMovement(mov['id'].toString());
      } catch (e) {
        debugPrint('Fallo silencioso en Movimientos: $e');
        break;
      }
    }
  }

  Future<void> _syncPayments() async {
    final pending = await _localStorage.getPendingPaymentUpdates();
    for (final update in List.from(pending)) {
      try {
        await _salesRepo.resyncPaymentUpdate(update);
        await _localStorage.removePendingPaymentUpdate(update['id_venta'].toString());
      } catch (e) {
        debugPrint('Fallo silencioso en Abonos: $e');
        break;
      }
    }
  }

  Future<void> forceSync() => _syncPending();
}

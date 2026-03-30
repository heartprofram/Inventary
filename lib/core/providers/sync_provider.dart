import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import 'core_providers.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  final salesRepo = ref.watch(salesRepositoryProvider);
  final movementRepo = ref.watch(movementRepositoryProvider);

  final service = SyncService(
    localStorage: localStorage,
    salesRepo: salesRepo,
    movementRepo: movementRepo,
    // SOLUCIÓN: Invalida el provider para que la UI se redibuje automáticamente
    onSyncComplete: () => ref.invalidate(pendingSyncCountProvider),
  );

  // SOLUCIÓN: Asegurar que el stream se cancele cuando el provider se destruya
  ref.onDispose(() => service.dispose());

  return service;
});

final pendingSyncCountProvider = StreamProvider<int>((ref) async* {
  final local = ref.read(localStorageServiceProvider);
  int lastCount = -1;
  
  while (true) {
    int currentCount = 0;
    try {
      final sales = await local.getPendingSales();
      final inv = await local.getPendingInventoryUpdates();
      final mov = await local.getPendingMovements();
      final pay = await local.getPendingPaymentUpdates();
      currentCount = sales.length + inv.length + mov.length + pay.length;
    } catch (_) {}

    // Solo actualiza la interfaz si el número cambió
    if (currentCount != lastCount) {
      lastCount = currentCount;
      yield currentCount;
    }
    // Revisa silenciosamente cada 2 segundos
    await Future.delayed(const Duration(seconds: 2));
  }
});


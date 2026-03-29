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

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final localStorage = ref.watch(localStorageServiceProvider);
  return localStorage.getPendingCount();
});

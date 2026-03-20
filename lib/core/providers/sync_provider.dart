import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import 'core_providers.dart';

/// Provider que expone el SyncService para uso global.
final syncServiceProvider = Provider<SyncService>((ref) {
  final localStorage = ref.watch(localStorageServiceProvider);
  final salesRepo = ref.watch(salesRepositoryProvider);
  final movementRepo = ref.watch(movementRepositoryProvider);

  return SyncService(
    localStorage: localStorage,
    salesRepo: salesRepo,
    movementRepo: movementRepo,
  );
});

/// Provider reactivo que expone cuántas operaciones están pendientes de sincronizar.
/// Útil para mostrar un badge o indicador en la UI.
final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final localStorage = ref.watch(localStorageServiceProvider);
  return localStorage.getPendingCount();
});

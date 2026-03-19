import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/movement.dart';
import '../../../../core/providers/core_providers.dart';

final movementRepositoryProvider = Provider<MovementRepository>((ref) {
  final googleApi = ref.watch(googleApiServiceProvider);
  return MovementRepository(googleApi: googleApi);
});

class MovementsNotifier extends AsyncNotifier<List<Movement>> {
  @override
  Future<List<Movement>> build() async {
    return ref.watch(movementRepositoryProvider).getMovements();
  }

  Future<bool> addMovement(Movement movement) async {
    try {
      await ref.read(movementRepositoryProvider).addMovement(movement);
      // Recargar lista
      ref.invalidateSelf();
      return true;
    } catch (e) {
      return false;
    }
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

final movementsProvider = AsyncNotifierProvider<MovementsNotifier, List<Movement>>(() {
  return MovementsNotifier();
});

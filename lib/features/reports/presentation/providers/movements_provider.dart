import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/movement.dart';
import '../../../../core/providers/core_providers.dart';

// El repository provider ahora se encuentra en core_providers.dart

final movementsDaysProvider = StateProvider<int>((ref) => 30);

class MovementsNotifier extends AsyncNotifier<List<Movement>> {
  @override
  Future<List<Movement>> build() async {
    final days = ref.watch(movementsDaysProvider);
    return await ref.watch(movementRepositoryProvider).getMovements(days: days);
  }

  void loadAllHistory() {
    ref.read(movementsDaysProvider.notifier).state = 0;
  }

  Future<bool> addMovement(Movement movement) async {
    try {
      await ref.read(movementRepositoryProvider).addMovement(movement);
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
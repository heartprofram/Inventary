
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/features/sales/domain/entities/payment.dart';

// Provider to hold the list of payments for the current sale
final paymentsProvider = StateNotifierProvider<PaymentsNotifier, List<Payment>>((ref) {
  return PaymentsNotifier();
});

class PaymentsNotifier extends StateNotifier<List<Payment>> {
  PaymentsNotifier() : super([]);

  void addPayment(Payment payment) {
    state = [...state, payment];
  }

  void removePayment(Payment payment) {
    state = state.where((p) => p != payment).toList();
  }

  void clearPayments() {
    state = [];
  }

  double get totalPaid {
    return state.fold(0.0, (sum, payment) => sum + payment.amount);
  }
}

// Provider for the debtor's name
final debtorNameProvider = StateProvider<String?>((ref) => null);

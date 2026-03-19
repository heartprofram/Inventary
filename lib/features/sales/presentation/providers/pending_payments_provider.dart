import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/providers/core_providers.dart';
import 'package:inventary/features/sales/domain/sale.dart';
import 'package:inventary/features/sales/presentation/providers/cart_provider.dart';
import 'package:inventary/features/sales/presentation/providers/payment_provider.dart';
import 'package:inventary/features/sales/domain/entities/payment.dart';

class PendingPayment {
  final String idVenta;
  final String fecha;
  final double totalUsd;
  final String deudor;
  final List<Map<String, dynamic>> detallesProductos;

  PendingPayment({
    required this.idVenta,
    required this.fecha,
    required this.totalUsd,
    required this.deudor,
    required this.detallesProductos,
  });

  Sale toSale(double currentRate) {
    final details = detallesProductos.map((d) => SaleDetail(
      productId: d['id_producto'],
      productName: d['nombre_producto'],
      quantity: (d['cantidad'] as num).toInt(),
      unitPriceUSD: (d['precio_unitario_usd'] as num).toDouble(),
    )).toList();

    return Sale(
      id: idVenta,
      date: DateTime.parse(fecha),
      exchangeRate: currentRate,
      details: details,
      payments: [],
      debtorName: deudor,
    );
  }
}

final pendingPaymentsProvider = AsyncNotifierProvider<PendingPaymentsNotifier, List<PendingPayment>>(
  PendingPaymentsNotifier.new,
);

class PendingPaymentsNotifier extends AsyncNotifier<List<PendingPayment>> {
  @override
  Future<List<PendingPayment>> build() async {
    return [];
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchPending());
  }

  Future<List<PendingPayment>> _fetchPending() async {
    // Para simplificar, obtenemos el historial de ventas y filtramos las que tengan 'pendiente'
    final salesRepo = ref.read(salesRepositoryProvider);
    final allSales = await salesRepo.getSalesHistory();
    
    final pendingSales = allSales.where((sale) {
      return sale.payments.any((p) => p.method == PaymentMethods.pendiente);
    }).toList();

    return pendingSales.map((sale) => PendingPayment(
      idVenta: sale.id,
      fecha: sale.date.toIso8601String(),
      totalUsd: sale.totalUSD,
      deudor: sale.debtorName ?? '',
      detallesProductos: sale.details.map((d) => {
        'id_producto': d.productId,
        'nombre_producto': d.productName,
        'cantidad': d.quantity,
        'precio_unitario_usd': d.unitPriceUSD,
      }).toList(),
    )).toList();
  }

  Future<void> processPendingPayment(PendingPayment pending, WidgetRef ref, double currentRate) async {
    final sale = pending.toSale(currentRate);
    
    ref.read(cartProvider.notifier).clear();
    ref.read(paymentsProvider.notifier).clearPayments();
    
    for (var detail in sale.details) {
      ref.read(cartProvider.notifier).addProductByDetail(detail);
    }
    
    ref.read(debtorNameProvider.notifier).state = pending.deudor;
  }

  Future<void> updatePendingStatus(String idVenta, List<Payment> payments) async {
    final salesRepo = ref.read(salesRepositoryProvider);
    await salesRepo.updateSaleStatus(idVenta, payments);
    await refresh();
  }
}
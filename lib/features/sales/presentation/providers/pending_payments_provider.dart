import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart'; // <--- IMPORTACIÓN DIRECTA DE DIO
import 'package:inventary/features/sales/domain/sale.dart';
import 'package:inventary/features/sales/presentation/providers/cart_provider.dart';
import 'package:inventary/features/sales/presentation/providers/payment_provider.dart';
import 'package:inventary/features/sales/domain/entities/payment.dart';

// Creamos un proveedor local de Dio para no depender de core_providers
final dioProvider = Provider((ref) => Dio());

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
    final dio = ref.read(dioProvider); // Ahora leerá nuestro proveedor local
    final response = await dio.get('http://localhost:8081/api/ventas/pendientes');
    final List<dynamic> data = response.data;
    
    return data.map((json) => PendingPayment(
      idVenta: json['id_venta'],
      fecha: json['fecha'],
      totalUsd: (json['total_usd'] as num).toDouble(),
      deudor: json['deudor'] ?? '',
      detallesProductos: List<Map<String, dynamic>>.from(json['detalles_productos'] ?? []),
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
    final dio = ref.read(dioProvider); // Ahora leerá nuestro proveedor local
    await dio.put('http://localhost:8081/api/ventas/update_status', data: {
      'id_venta': idVenta,
      'metodos_pago': payments.map((p) => p.toJson()).toList(),
    });
    
    await refresh();
  }
}
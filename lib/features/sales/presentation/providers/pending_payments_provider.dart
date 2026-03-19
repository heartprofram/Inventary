import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/core_providers.dart';
import '../../domain/sale.dart';
import '../providers/sales_providers.dart';
import '../providers/cart_provider.dart';
import '../providers/payment_provider.dart';
import '../../../../core/constants/app_constants.dart';

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

// Provider para lista de pagos pendientes
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
    final dio = ref.read(dioProvider);
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
    // Cargar en carrito y pagos
    final sale = pending.toSale(currentRate);
    
    // Limpiar carrito actual
    ref.read(cartProvider.notifier).clear();
    ref.read(paymentsProvider.notifier).clearPayments();
    
    // Recargar productos del pendiente
    for (var detail in sale.details) {
      ref.read(cartProvider.notifier).addProductByDetail(detail);
    }
    
    // Configurar deudor para referencia
    ref.read(debtorNameProvider.notifier).state = pending.deudor;
  }

  Future<void> updatePendingStatus(String idVenta, List<Payment> payments) async {
    final dio = ref.read(dioProvider);
    await dio.put('http://localhost:8081/api/ventas/update_status', data: {
      'id_venta': idVenta,
      'metodos_pago': payments.map((p) => p.toJson()).toList(),
    });
    
    // Refresh lista
    await refresh();
  }
}

// Extension para addProductByDetail en cart_provider (se añadirá después)
extension CartNotifierExt on CartNotifier {
  void addProductByDetail(SaleDetail detail) {
    // Implementar lógica para agregar por detalle (simplificado)
    // Esto requerirá lookup del product completo normalmente
  }
}


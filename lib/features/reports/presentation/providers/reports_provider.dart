import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../sales/domain/sale.dart';
import '../../../sales/domain/entities/payment.dart'; // <-- IMPORTACIÓN FALTANTE AGREGADA
import '../../../../core/utils/pdf_invoice_generator.dart';
import '../../../../core/providers/core_providers.dart';

// Estructura de métricas diarias
class DailyReportMetrics {
  final List<Sale> sales;
  final double totalUSD;
  final double totalVES;
  final Map<String, double> paymentsUSD; 
  final Map<String, double> paymentsVES; 
  final bool isClosed;

  DailyReportMetrics({
    required this.sales,
    required this.totalUSD,
    required this.totalVES,
    required this.paymentsUSD,
    required this.paymentsVES,
    this.isClosed = false,
  });
}

// Notificador para extraer la data
class ReportsNotifier extends AsyncNotifier<DailyReportMetrics> {
  @override
  Future<DailyReportMetrics> build() async {
    return _fetchTodayMetrics();
  }

  Future<DailyReportMetrics> _fetchTodayMetrics() async {
    final repo = ref.read(reportsRepositoryProvider);
    final sales = await repo.getDailySales(DateTime.now());

    double totalUSD = 0.0;
    double totalVESBS = 0.0; // Solo lo que es BS (no Efectivo USD)

    final Map<String, double> paymentsUSD = {};
    final Map<String, double> paymentsVES = {};

    for (final sale in sales) {
      totalUSD += sale.totalUSD;
      for (final payment in sale.payments) {
        final label = payment.method; // <-- CORREGIDO (Sin el .label() que causaba error)
        
        paymentsUSD.update(label, (v) => v + payment.amount, ifAbsent: () => payment.amount);
        
        // Lógica de separación: Efectivo USD no se convierte a VES para el total de bolívares en caja
        if (payment.method == PaymentMethods.efectivoUsd || payment.method == 'Efectivo USD') {
          paymentsVES.update(label, (v) => v + 0.0, ifAbsent: () => 0.0);
        } else if (payment.method != PaymentMethods.pendiente && payment.method != 'Pendiente (Por Cobrar)') {
          final amountVES = payment.amount * sale.exchangeRate;
          totalVESBS += amountVES;
          paymentsVES.update(label, (v) => v + amountVES, ifAbsent: () => amountVES);
        }
      }
    }

    return DailyReportMetrics(
      sales: sales,
      totalUSD: totalUSD,
      totalVES: totalVESBS,
      paymentsUSD: paymentsUSD,
      paymentsVES: paymentsVES,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final metrics = await _fetchTodayMetrics();
      state = AsyncValue.data(metrics);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> generateAndCloseRegister() async {
    final currentMetrics = state.value;
    if (currentMetrics == null || currentMetrics.sales.isEmpty) return;

    state = const AsyncValue.loading();

    try {
      final pdfBytes = await PdfInvoiceGenerator.generateZReport(
        currentMetrics.sales,
        currentMetrics.totalUSD,
        currentMetrics.totalVES,
      );

      await Printing.sharePdf(
        bytes: pdfBytes, 
        filename: 'ReporteZ_${DateTime.now().toIso8601String().split("T")[0]}.pdf'
      );

      state = AsyncValue.data(DailyReportMetrics(
        sales: currentMetrics.sales,
        totalUSD: currentMetrics.totalUSD,
        totalVES: currentMetrics.totalVES,
        paymentsUSD: currentMetrics.paymentsUSD,
        paymentsVES: currentMetrics.paymentsVES,
        isClosed: true,
      ));

    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final reportsProvider = AsyncNotifierProvider<ReportsNotifier, DailyReportMetrics>(() {
  return ReportsNotifier();
});
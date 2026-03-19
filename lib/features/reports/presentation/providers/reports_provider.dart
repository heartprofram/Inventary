import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../sales/domain/sale.dart';
import '../../../../core/utils/pdf_invoice_generator.dart';
import '../../../../core/providers/core_providers.dart';

// El repository provider ahora se encuentra en core_providers.dart

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
    final sales = await repo.getDailySales();

    final totalUSD = sales.fold(0.0, (sum, sale) => sum + sale.totalUSD);
    final totalVES = sales.fold(0.0, (sum, sale) => sum + sale.totalVES);
    
    // Desglose por método de pago
    final Map<String, double> paymentsUSD = {};
    final Map<String, double> paymentsVES = {};
    for (final sale in sales) {
      for (final payment in sale.payments) {
        paymentsUSD.update(
          PaymentMethods.label(payment.method),
          (value) => value + payment.amount,
          ifAbsent: () => payment.amount,
        );
        paymentsVES.update(
          PaymentMethods.label(payment.method),
          (value) => value + payment.amount * sale.exchangeRate,
          ifAbsent: () => payment.amount * sale.exchangeRate,
        );
      }
    }

    return DailyReportMetrics(
      sales: sales,
      totalUSD: totalUSD,
      totalVES: totalVES,
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
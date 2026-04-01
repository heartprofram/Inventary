import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// ─── IMPORTACIONES ABSOLUTAS (A PRUEBA DE FALLOS DE RUTAS) ───
import 'package:inventary/core/providers/core_providers.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import 'package:inventary/core/widgets/custom_snackbar.dart';
import 'package:inventary/core/utils/pdf_invoice_generator.dart';
import 'package:inventary/features/sales/domain/sale.dart';
import 'package:inventary/features/sales/domain/entities/payment.dart';
import 'package:inventary/features/sales/presentation/providers/sales_providers.dart';
import 'package:inventary/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:inventary/features/inventory/domain/product.dart';
import 'package:inventary/features/settings/presentation/providers/settings_provider.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  List<Sale> _cachedSales = [];

  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesHistoryProvider);
    final days = ref.watch(salesHistoryDaysProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de Ventas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _cachedSales.isEmpty
                ? null
                : () => _showExportMenu(context),
            icon: const Icon(Icons.picture_as_pdf, size: 20),
            label: const Text(
              'Exportar Reporte',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: salesAsync.when(
        loading: () => const ShimmerList(itemCount: 8),
        error: (err, stack) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          message: err.toString(),
        ),
        data: (sales) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _cachedSales.length != sales.length) {
              setState(() => _cachedSales = sales);
            }
          });

          if (sales.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Historial vacío',
              message: days > 0
                  ? 'No hay ventas en los últimos $days días.'
                  : 'Aún no se han completado ventas en el sistema.',
              onAction: days > 0
                  ? () =>
                        ref.read(salesHistoryProvider.notifier).loadAllHistory()
                  : _refresh,
              actionLabel: days > 0 ? 'Cargar Histórico Completo' : 'Refrescar',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sales.length + (days > 0 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == sales.length && days > 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(salesHistoryProvider.notifier)
                        .loadAllHistory(),
                    icon: const Icon(Icons.history),
                    label: const Text(
                      'Mostrando últimos 30 días. Cargar histórico completo.',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }
              final sale = sales[index];
              return _SaleCard(
                sale: sale,
                onRefresh: () => ref.refresh(salesHistoryProvider),
              );
            },
          );
        },
      ),
    );
  }

  void _showExportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Exportar Reporte',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _ExportOption(
              icon: Icons.today,
              label: 'Día Anterior (Ayer)',
              onTap: () => _handleExport('ayer'),
            ),
            _ExportOption(
              icon: Icons.date_range,
              label: 'Esta Semana',
              onTap: () => _handleExport('semana'),
            ),
            _ExportOption(
              icon: Icons.calendar_month,
              label: 'Este Mes',
              onTap: () => _handleExport('mes'),
            ),
            _ExportOption(
              icon: Icons.public,
              label: 'Histórico Global',
              onTap: () => _handleExport('global'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(String period) async {
    Navigator.pop(context); // Cierra el menú inferior

    // Leemos el historial directamente del provider para evitar la caché vacía
    final allSales = ref.read(salesHistoryProvider).value;

    if (allSales == null || allSales.isEmpty) {
      CustomSnackBar.error(
        context,
        'El historial está vacío. No hay datos para exportar.',
      );
      return;
    }

    final now = DateTime.now();
    List<Sale> filteredSales = [];
    String periodName = '';

    if (period == 'ayer') {
      periodName = 'Ayer';
      final yesterday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final today = DateTime(now.year, now.month, now.day);
      filteredSales = allSales
          .where(
            (s) =>
                s.date.compareTo(yesterday) >= 0 && s.date.compareTo(today) < 0,
          )
          .toList();
    } else if (period == 'semana') {
      periodName = 'Esta Semana';
      final lastWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 7));
      filteredSales = allSales
          .where((s) => s.date.compareTo(lastWeek) >= 0)
          .toList();
    } else if (period == 'mes') {
      periodName = 'Este Mes';
      filteredSales = allSales
          .where((s) => s.date.month == now.month && s.date.year == now.year)
          .toList();
    } else {
      periodName = 'Global';
      filteredSales = allSales;
    }

    if (filteredSales.isEmpty) {
      CustomSnackBar.warning(
        context,
        'No hay ninguna venta registrada para: $periodName',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfBytes = await PdfInvoiceGenerator.generateSalesReport(
        filteredSales,
        periodName,
      );
      if (mounted) {
        Navigator.pop(context); // Cierra el loading
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Reporte_$periodName.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        CustomSnackBar.error(context, 'Error al generar PDF: $e');
      }
    }
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ExportOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _SaleCard extends ConsumerWidget {
  final Sale sale;
  final VoidCallback onRefresh;

  const _SaleCard({required this.sale, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        backgroundColor: Colors.teal.withOpacity(0.02),
        collapsedBackgroundColor: Colors.white,
        title: Text(
          'Venta #${sale.id.split('-').last.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(sale.date)} • ${sale.paymentMethodLabel}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ExchangeSaleScreen(sale: sale, onRefresh: onRefresh),
                ),
              );
            } else if (value == 'delete') {
              _deleteSale(context, ref);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, size: 20, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Devolución / Cambio'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Text('Anular Venta Completa'),
                ],
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              children: [
                if (sale.debtorName != null && sale.debtorName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Deudor: ${sale.debtorName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ...sale.details.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${detail.quantity}x',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            detail.productName,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '\$${detail.subtotalUSD.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Pagado:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '\$${sale.totalUSD.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteSale(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular Venta'),
        content: const Text(
          '¿Estás seguro de anular esta venta? El stock de los productos será restaurado al inventario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await ref.read(salesRepositoryProvider).deleteSale(sale);
        if (context.mounted) {
          Navigator.pop(context);
          CustomSnackBar.success(context, 'Venta anulada y stock restaurado');
          onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          CustomSnackBar.error(context, 'Error al anular: $e');
        }
      }
    }
  }
}

class ExchangeSaleScreen extends ConsumerStatefulWidget {
  final Sale sale;
  final VoidCallback onRefresh;

  const ExchangeSaleScreen({
    super.key,
    required this.sale,
    required this.onRefresh,
  });

  @override
  ConsumerState<ExchangeSaleScreen> createState() => _ExchangeSaleScreenState();
}

class _ExchangeSaleScreenState extends ConsumerState<ExchangeSaleScreen> {
  late List<SaleDetail> currentDetails;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    currentDetails = widget.sale.details
        .map(
          (d) => SaleDetail(
            productId: d.productId,
            productName: d.productName,
            quantity: d.quantity,
            unitPriceUSD: d.unitPriceUSD,
          ),
        )
        .toList();
  }

  double get originalTotalUSD => widget.sale.totalUSD;
  double get currentTotalUSD =>
      currentDetails.fold(0.0, (sum, d) => sum + d.subtotalUSD);
  double get differenceUSD => currentTotalUSD - originalTotalUSD;

  void _increment(int index) {
    setState(() {
      currentDetails[index] = SaleDetail(
        productId: currentDetails[index].productId,
        productName: currentDetails[index].productName,
        quantity: currentDetails[index].quantity + 1,
        unitPriceUSD: currentDetails[index].unitPriceUSD,
      );
    });
  }

  void _decrement(int index) {
    setState(() {
      if (currentDetails[index].quantity > 1) {
        currentDetails[index] = SaleDetail(
          productId: currentDetails[index].productId,
          productName: currentDetails[index].productName,
          quantity: currentDetails[index].quantity - 1,
          unitPriceUSD: currentDetails[index].unitPriceUSD,
        );
      } else {
        currentDetails.removeAt(index);
      }
    });
  }

  void _showAddProductModal() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final inventoryAsync = ref.watch(inventoryProvider);

            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar producto para añadir...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (val) =>
                          setModalState(() => searchQuery = val),
                    ),
                  ),
                  Expanded(
                    child: inventoryAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err')),
                      data: (products) {
                        final filtered = products
                            .where(
                              (p) =>
                                  p.name.toLowerCase().contains(
                                    searchQuery.toLowerCase(),
                                  ) ||
                                  p.barCode.toLowerCase().contains(
                                    searchQuery.toLowerCase(),
                                  ),
                            )
                            .toList();
                        if (filtered.isEmpty)
                          return const Center(
                            child: Text('No se encontraron productos'),
                          );

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final p = filtered[i];
                            return ListTile(
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Stock: ${p.stockQuantity} | P.V: \$${p.salePriceUSD}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.teal,
                                  size: 30,
                                ),
                                onPressed: () {
                                  if (p.stockQuantity <= 0) {
                                    CustomSnackBar.error(
                                      context,
                                      'No hay stock disponible',
                                    );
                                    return;
                                  }
                                  setState(() {
                                    final existingIdx = currentDetails
                                        .indexWhere((d) => d.productId == p.id);
                                    if (existingIdx >= 0) {
                                      _increment(existingIdx);
                                    } else {
                                      currentDetails.add(
                                        SaleDetail(
                                          productId: p.id,
                                          productName: p.name,
                                          quantity: 1,
                                          unitPriceUSD: p.salePriceUSD,
                                        ),
                                      );
                                    }
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diff = differenceUSD;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cambio / Devolución',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Factura Original:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '\$${originalTotalUSD.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: currentDetails.isEmpty
                ? const Center(
                    child: Text(
                      'No quedan artículos.\nGuarda para anular la venta completa.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: currentDetails.length,
                    itemBuilder: (context, index) {
                      final detail = currentDetails[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Unidad: \$${detail.unitPriceUSD.toStringAsFixed(2)}  |  Total: \$${detail.subtotalUSD.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _decrement(index),
                                    ),
                                    Text(
                                      '${detail.quantity}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _increment(index),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showAddProductModal,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Añadir Artículo al Cambio'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: const BorderSide(color: Colors.teal),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nuevo Total:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${currentTotalUSD.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (diff != 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: diff > 0
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            diff > 0
                                ? 'Falta por pagar:'
                                : 'A devolver al cliente:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: diff > 0
                                  ? Colors.orange[800]
                                  : Colors.green[800],
                            ),
                          ),
                          Text(
                            '\$${diff.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: diff > 0
                                  ? Colors.orange[800]
                                  : Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () => _handleConfirmation(diff),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Procesar Cambio / Devolución',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleConfirmation(double diff) {
    if (currentDetails.isEmpty) {
      _processFinalSave([]);
      return;
    }

    if (diff > 0) {
      _showExtraPaymentDialog(diff);
    } else if (diff < 0) {
      _processRefund(diff.abs());
    } else {
      _processFinalSave(widget.sale.payments);
    }
  }

  void _processRefund(double refundAmount) {
    List<Payment> adjustedPayments = List.from(widget.sale.payments);
    double remainingToRefund = refundAmount;

    for (int i = adjustedPayments.length - 1; i >= 0; i--) {
      if (remainingToRefund <= 0) break;

      double pAmount = adjustedPayments[i].amount;
      if (pAmount <= remainingToRefund) {
        remainingToRefund -= pAmount;
        adjustedPayments.removeAt(i);
      } else {
        adjustedPayments[i] = Payment(
          method: adjustedPayments[i].method,
          amount: pAmount - remainingToRefund,
        );
        remainingToRefund = 0;
      }
    }
    _processFinalSave(adjustedPayments);
  }

  void _showExtraPaymentDialog(double amountToPayUSD) {
    final rate = ref.read(exchangeRateProvider).value?.rate ?? 36.0;
    final usdController = TextEditingController();
    final bsController = TextEditingController();
    final pmController = TextEditingController();
    final puntoController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double getEnteredUSD() {
              final u =
                  double.tryParse(usdController.text.replaceAll(',', '.')) ??
                  0.0;
              final b =
                  double.tryParse(bsController.text.replaceAll(',', '.')) ??
                  0.0;
              final pm =
                  double.tryParse(pmController.text.replaceAll(',', '.')) ??
                  0.0;
              final pt =
                  double.tryParse(puntoController.text.replaceAll(',', '.')) ??
                  0.0;
              return u + ((b + pm + pt) / rate);
            }

            final entered = getEnteredUSD();
            final remaining = amountToPayUSD - entered;
            final isComplete = remaining <= 0.01;

            Widget buildPaymentField(
              String label,
              IconData icon,
              TextEditingController controller,
              bool isUSD,
            ) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: label,
                    prefixIcon: Icon(icon, color: Colors.grey),
                    suffixIcon: remaining > 0.001
                        ? IconButton(
                            icon: const Icon(
                              Icons.flash_on,
                              color: Colors.orange,
                            ),
                            tooltip: 'Autocompletar el resto',
                            onPressed: () {
                              final currentEntered = getEnteredUSD();
                              final missing = amountToPayUSD - currentEntered;
                              if (missing > 0.001) {
                                final currentVal =
                                    double.tryParse(
                                      controller.text.replaceAll(',', '.'),
                                    ) ??
                                    0.0;
                                final addition = isUSD
                                    ? missing
                                    : (missing * rate);
                                controller.text = (currentVal + addition)
                                    .toStringAsFixed(2);
                                setModalState(() {});
                              }
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),
              );
            }

            return AlertDialog(
              title: const Text('Completar Pago'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Falta Pagar:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            '\$${remaining > 0 ? remaining.toStringAsFixed(2) : "0.00"}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Bs. ${(remaining > 0 ? remaining * rate : 0).toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    buildPaymentField(
                      'Efectivo (\$)',
                      Icons.attach_money,
                      usdController,
                      true,
                    ),
                    buildPaymentField(
                      'Efectivo (Bs)',
                      Icons.money,
                      bsController,
                      false,
                    ),
                    buildPaymentField(
                      'Pago Móvil (Bs)',
                      Icons.phone_android,
                      pmController,
                      false,
                    ),
                    buildPaymentField(
                      'Punto de Venta (Bs)',
                      Icons.credit_card,
                      puntoController,
                      false,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isComplete
                      ? () {
                          List<Payment> newPayments = [];
                          if ((double.tryParse(
                                    usdController.text.replaceAll(',', '.'),
                                  ) ??
                                  0) >
                              0)
                            newPayments.add(
                              Payment(
                                method: PaymentMethods.efectivoUsd,
                                amount: double.parse(
                                  usdController.text.replaceAll(',', '.'),
                                ),
                              ),
                            );
                          if ((double.tryParse(
                                    bsController.text.replaceAll(',', '.'),
                                  ) ??
                                  0) >
                              0)
                            newPayments.add(
                              Payment(
                                method: PaymentMethods.efectivoVes,
                                amount:
                                    double.parse(
                                      bsController.text.replaceAll(',', '.'),
                                    ) /
                                    rate,
                              ),
                            );
                          if ((double.tryParse(
                                    pmController.text.replaceAll(',', '.'),
                                  ) ??
                                  0) >
                              0)
                            newPayments.add(
                              Payment(
                                method: PaymentMethods.pagoMovil,
                                amount:
                                    double.parse(
                                      pmController.text.replaceAll(',', '.'),
                                    ) /
                                    rate,
                              ),
                            );
                          if ((double.tryParse(
                                    puntoController.text.replaceAll(',', '.'),
                                  ) ??
                                  0) >
                              0)
                            newPayments.add(
                              Payment(
                                method: PaymentMethods.puntoDeVenta,
                                amount:
                                    double.parse(
                                      puntoController.text.replaceAll(',', '.'),
                                    ) /
                                    rate,
                              ),
                            );

                          Navigator.pop(context);
                          List<Payment> finalPayments = [
                            ...widget.sale.payments,
                            ...newPayments,
                          ];
                          _processFinalSave(finalPayments);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processFinalSave(List<Payment> adjustedPayments) async {
    setState(() => isSaving = true);
    try {
      if (currentDetails.isEmpty) {
        await ref.read(salesRepositoryProvider).deleteSale(widget.sale);
      } else {
        final newSale =
            Sale(
              id: widget.sale.id,
              date: widget.sale.date,
              exchangeRate: widget.sale.exchangeRate,
              details: currentDetails,
              payments: adjustedPayments,
              debtorName: widget.sale.debtorName,
            )..overrideTotals(
              currentTotalUSD,
              currentTotalUSD * widget.sale.exchangeRate,
            );

        await ref
            .read(salesRepositoryProvider)
            .updateSale(widget.sale, newSale);
      }

      if (mounted) {
        CustomSnackBar.success(context, 'Operación procesada correctamente');
        widget.onRefresh();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.error(context, 'Error al actualizar: $e');
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}

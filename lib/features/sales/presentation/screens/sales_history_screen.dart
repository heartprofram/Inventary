import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../../../core/utils/pdf_invoice_generator.dart';
import '../../domain/sale.dart';
import 'package:intl/intl.dart';

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
    final salesRepo = ref.watch(salesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Ventas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _cachedSales.isEmpty ? null : () => _showExportMenu(context),
            icon: const Icon(Icons.picture_as_pdf, size: 20),
            label: const Text('Exportar Reporte', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: FutureBuilder<List<Sale>>(
        future: salesRepo.getSalesHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerList(itemCount: 8);
          }
          if (snapshot.hasError) {
            return EmptyState(icon: Icons.error_outline, title: 'Error', message: snapshot.error.toString());
          }

          _cachedSales = snapshot.data ?? [];

          if (_cachedSales.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Historial vacío',
              message: 'Aún no se han completado ventas en el sistema.',
              onAction: _refresh,
              actionLabel: 'Refrescar',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _cachedSales.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sale = _cachedSales[index];
              return _SaleCard(sale: sale, onRefresh: _refresh);
            },
          );
        },
      ),
    );
  }

  void _showExportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Exportar Reporte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    Navigator.pop(context);
    final now = DateTime.now();
    List<Sale> filteredSales = [];
    String periodName = '';

    if (period == 'ayer') {
      periodName = 'Ayer';
      final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      final today = DateTime(now.year, now.month, now.day);
      filteredSales = _cachedSales.where((s) => s.date.isAfter(yesterday) && s.date.isBefore(today)).toList();
    } else if (period == 'semana') {
      periodName = 'Esta Semana';
      final lastWeek = now.subtract(const Duration(days: 7));
      filteredSales = _cachedSales.where((s) => s.date.isAfter(lastWeek)).toList();
    } else if (period == 'mes') {
      periodName = 'Este Mes';
      filteredSales = _cachedSales.where((s) => s.date.month == now.month && s.date.year == now.year).toList();
    } else {
      periodName = 'Global';
      filteredSales = _cachedSales;
    }

    if (filteredSales.isEmpty) {
      CustomSnackBar.error(context, 'No hay ventas en el período: $periodName');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pdfBytes = await PdfInvoiceGenerator.generateSalesReport(filteredSales, periodName);
      if (mounted) {
        Navigator.pop(context); // Close loading
        await Printing.sharePdf(bytes: pdfBytes, filename: 'Reporte_$periodName.pdf');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        CustomSnackBar.error(context, 'Error al generar PDF: $e');
      }
    }
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExportOption({required this.icon, required this.label, required this.onTap});

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
              _showEditSaleDialog(context, ref, sale);
            } else if (value == 'delete') {
              _deleteSale(context, ref);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Editar / Devolución'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Text('Anular Venta'),
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
                        const Icon(Icons.person_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text('Deudor: ${sale.debtorName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                  ),
                ...sale.details.map((detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: Text('${detail.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(detail.productName, style: const TextStyle(fontSize: 14))),
                      Text('\$${detail.subtotalUSD.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
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
        content: const Text('¿Estás seguro de anular esta venta? El stock de los productos será restaurado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        await ref.read(salesRepositoryProvider).deleteSale(sale);
        if (context.mounted) {
          Navigator.pop(context); // close loading
          CustomSnackBar.success(context, 'Venta anulada y stock restaurado');
          onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // close loading
          CustomSnackBar.error(context, 'Error al anular: $e');
        }
      }
    }
  }

  void _showEditSaleDialog(BuildContext context, WidgetRef ref, Sale sale) {
    showDialog(
      context: context,
      builder: (context) => EditSaleDialog(sale: sale, onRefresh: onRefresh),
    );
  }
}

class EditSaleDialog extends StatefulWidget {
  final Sale sale;
  final VoidCallback onRefresh;

  const EditSaleDialog({super.key, required this.sale, required this.onRefresh});

  @override
  State<EditSaleDialog> createState() => _EditSaleDialogState();
}

class _EditSaleDialogState extends State<EditSaleDialog> {
  late List<SaleDetail> currentDetails;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    currentDetails = List.from(widget.sale.details);
  }

  double get currentTotalUSD => currentDetails.fold(0.0, (sum, d) => sum + d.subtotalUSD);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Venta / Devolución'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Desliza un producto para eliminarlo (devolución):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: currentDetails.length,
                itemBuilder: (context, index) {
                  final detail = currentDetails[index];
                  return Dismissible(
                    key: Key('${detail.productId}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.redAccent,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      setState(() {
                        currentDetails.removeAt(index);
                      });
                    },
                    child: ListTile(
                      title: Text(detail.productName),
                      subtitle: Text('${detail.quantity}x \$${detail.unitPriceUSD}'),
                      trailing: Text('\$${detail.subtotalUSD.toStringAsFixed(2)}'),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nuevo Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('\$${currentTotalUSD.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        Consumer(
          builder: (context, ref, child) {
            return ElevatedButton(
              onPressed: isSaving ? null : () => _saveChanges(context, ref),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar'),
            );
          },
        ),
      ],
    );
  }

  Future<void> _saveChanges(BuildContext context, WidgetRef ref) async {
    setState(() => isSaving = true);
    try {
      final newSale = Sale(
        id: widget.sale.id,
        date: widget.sale.date,
        exchangeRate: widget.sale.exchangeRate,
        details: currentDetails,
        payments: widget.sale.payments, // Mantener pagos originales por ahora o ajustarlos? 
        // El usuario pide recalcular totales y llamar a updateSale(oldSale, newSale)
        debtorName: widget.sale.debtorName,
      );

      await ref.read(salesRepositoryProvider).updateSale(widget.sale, newSale);
      if (context.mounted) {
        Navigator.pop(context);
        CustomSnackBar.success(context, 'Venta actualizada correctamente');
        widget.onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.error(context, 'Error al actualizar: $e');
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }
}

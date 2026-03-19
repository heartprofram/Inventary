import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/custom_snackbar.dart';
import '../../domain/sale.dart';
import 'package:intl/intl.dart';
import 'edit_sale_screen.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  void _refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final salesRepo = ref.watch(salesRepositoryProvider);

    return Scaffold(
      body: FutureBuilder<List<Sale>>(
        future: salesRepo.getSalesHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerList(itemCount: 8);
          }
          if (snapshot.hasError) {
            return EmptyState(icon: Icons.error_outline, title: 'Error', message: snapshot.error.toString());
          }

          final sales = snapshot.data ?? [];

          if (sales.isEmpty) {
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
            itemCount: sales.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sale = sales[index];
              return _SaleCard(sale: sale, onRefresh: _refresh);
            },
          );
        },
      ),
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\$${sale.totalUSD.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Bs. ${sale.totalVES.toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontSize: 11)),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              children: [
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
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editSale(context),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text('Editar'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteSale(context, ref),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text('Eliminar'),
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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
        title: const Text('Eliminar Venta'),
        content: const Text('Esta acción revertirá el stock de los productos. ¿Confirmar eliminación?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        await ref.read(salesRepositoryProvider).deleteSale(sale);
        if (context.mounted) {
          Navigator.pop(context); // close loading
          CustomSnackBar.success(context, 'Venta eliminada exitosamente');
          onRefresh();
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // close loading
          CustomSnackBar.error(context, 'Error al eliminar: $e');
        }
      }
    }
  }

  void _editSale(BuildContext context) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditSaleScreen(sale: sale)));
    if (result == true) onRefresh();
  }
}

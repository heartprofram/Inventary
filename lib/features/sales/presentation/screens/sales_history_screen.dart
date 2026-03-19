import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final sales = snapshot.data ?? [];

          if (sales.isEmpty) {
            return const Center(child: Text('No hay ventas registradas.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sales.length,
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

  void _deleteSale(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Venta'),
        content: const Text('¿Estás seguro de eliminar esta venta y devolver los productos al inventario? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      try {
        final repo = ref.read(salesRepositoryProvider);
        await repo.deleteSale(sale);
        Navigator.pop(context); // close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta eliminada exitosamente')));
        onRefresh();
      } catch (e) {
        Navigator.pop(context); // close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _editSale(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditSaleScreen(sale: sale)),
    );
    if (result == true) {
      onRefresh(); // Refresh if edit was saved
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          'Venta #${sale.id}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(sale.date)} - ${sale.paymentMethodLabel}',
        ),
        trailing: Text(
          '\$${sale.totalUSD.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        children: [
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Producto', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Precio', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ...sale.details.map((detail) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(flex: 3, child: Text(detail.productName, maxLines: 1)),
                Expanded(flex: 1, child: Text('${detail.quantity}', textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('\$${detail.unitPriceUSD.toStringAsFixed(2)}', textAlign: TextAlign.right)),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editSale(context),
                      tooltip: 'Editar Venta',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteSale(context, ref),
                      tooltip: 'Eliminar Venta',
                    ),
                  ],
                ),
                Text(
                  'Total Bs: ${sale.totalVES.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

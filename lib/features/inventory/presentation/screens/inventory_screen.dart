import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import 'package:inventary/features/inventory/domain/product.dart';
import 'package:inventary/core/providers/core_providers.dart';
import 'package:inventary/features/settings/presentation/providers/settings_provider.dart';
import '../providers/inventory_provider.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';


// Provider local para filtro de búsqueda en inventario
final inventorySearchQueryProvider = StateProvider<String>((ref) => '');

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryState = ref.watch(inventoryProvider);
    final searchQuery = ref.watch(inventorySearchQueryProvider);

    // Calcular Valor Total de Venta (USD)
    final totalSalesValue = inventoryState.when(
      data: (products) => products.fold<double>(0, (sum, p) => sum + (p.salePriceUSD * p.stockQuantity)),
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );

    return Scaffold(
      body: Column(
        children: [
          _buildInventoryHeader(context, ref, totalSalesValue),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              onChanged: (value) => ref.read(inventorySearchQueryProvider.notifier).state = value,
              hintText: 'Buscar productos por nombre o código...',
              leading: const Icon(Icons.search, color: Colors.teal),
              trailing: [
                if (searchQuery.isNotEmpty)
                  IconButton(
                    onPressed: () => ref.read(inventorySearchQueryProvider.notifier).state = '',
                    icon: const Icon(Icons.clear),
                  ),
              ],
              elevation: MaterialStateProperty.all(1),
              backgroundColor: MaterialStateProperty.all(Colors.grey[100]),
              shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          Expanded(
            child: inventoryState.when(
              data: (products) {
                final filteredProducts = products.where((p) {
                  return p.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
                         p.barCode.toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();

                if (filteredProducts.isEmpty) {
                  return EmptyState(
                    icon: searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                    title: searchQuery.isEmpty ? 'Inventario vacío' : 'No se encontraron coincidencias',
                    message: searchQuery.isEmpty 
                        ? 'Comienza agregando tu primer producto.' 
                        : 'Prueba buscando con otros términos.',
                    onAction: searchQuery.isEmpty ? () => _navigateToAdd(context) : () => ref.read(inventorySearchQueryProvider.notifier).state = '',
                    actionLabel: searchQuery.isEmpty ? 'Nuevo Producto' : 'Limpiar Búsqueda',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final isLowStock = product.stockQuantity < 5;
                    
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isLowStock ? Colors.orange.withOpacity(0.5) : Colors.grey[200]!,
                          width: isLowStock ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: isLowStock ? Colors.orange.withOpacity(0.1) : Colors.teal.withOpacity(0.1),
                          child: Icon(
                            isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2,
                            color: isLowStock ? Colors.orange[800] : Colors.teal,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Código: ${product.barCode}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text('ID: ${product.id}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildBadge('P.V: \$${product.salePriceUSD}', Colors.green),
                                _buildBadge(
                                  'Stock: ${product.stockQuantity}', 
                                  isLowStock ? Colors.red : Colors.blueGrey,
                                  isBold: isLowStock,
                                ),
                              ],
                            ),
                          ],
                        ),
                        // BOTONES SIMÉTRICOS A LA DERECHA
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _navigateToEdit(context, product),
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              tooltip: 'Editar Producto',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.withOpacity(0.1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _showSurtirDialog(context, ref, product),
                              icon: const Icon(Icons.add_business_outlined, color: Colors.teal),
                              tooltip: 'Surtir Stock',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.teal.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const ShimmerList(itemCount: 8),
              error: (err, __) => EmptyState(icon: Icons.error_outline, title: 'Error al cargar', message: err.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAdd(context),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Producto', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildInventoryHeader(BuildContext context, WidgetRef ref, double totalValue) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.teal.withOpacity(0.1))),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Valor Total de Venta', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '\$ ${totalValue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.teal),
              ),
            ],
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: () => ref.read(inventoryProvider.notifier).refresh(),
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar con Google Sheets',
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color, 
          fontSize: 12, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal
        ),
      ),
    );
  }

  void _showSurtirDialog(BuildContext context, WidgetRef ref, Product product) {
    final quantityController = TextEditingController(text: '0');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Surtir: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock actual: ${product.stockQuantity}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cantidad a agregar',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = int.tryParse(quantityController.text) ?? 0;
              if (qty > 0) {
                Navigator.pop(context);
                // Llama a updateStock sumando la cantidad
                await ref.read(productRepositoryProvider).updateStock(
                  product.id, 
                  product.stockQuantity + qty
                );
                ref.invalidate(inventoryProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stock actualizado')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _navigateToAdd(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
  }

  void _navigateToEdit(BuildContext context, Product product) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(product: product)));
  }
}

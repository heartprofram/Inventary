import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import '../providers/inventory_provider.dart';
import 'add_product_screen.dart';

// Provider local para filtro de búsqueda en inventario
final inventorySearchQueryProvider = StateProvider<String>((ref) => '');

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryState = ref.watch(inventoryProvider);
    final searchQuery = ref.watch(inventorySearchQueryProvider);

    return Scaffold(
      body: Column(
        children: [
          _buildInventoryHeader(context, ref),
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
                            Text('ID: ${product.barCode}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildBadge('P.V: \$${product.salePriceUSD}', Colors.green),
                                const SizedBox(width: 8),
                                _buildBadge(
                                  'Stock: ${product.stockQuantity}', 
                                  isLowStock ? Colors.red : Colors.blueGrey,
                                  isBold: isLowStock,
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          onPressed: () {}, // Futuro: editar producto
                          icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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

  Widget _buildInventoryHeader(BuildContext context, WidgetRef ref) {
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
              const Text('Valor del Inventario', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '\$${ref.read(inventoryProvider.notifier).totalInventoryValueVES.toStringAsFixed(2)}',
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

  void _navigateToAdd(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
  }
}

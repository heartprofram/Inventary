import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';
import 'add_product_screen.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchamos el estado del provider de inventario
    final inventoryState = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario Disponible'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar desde Google Sheets',
            onPressed: () {
              ref.read(inventoryProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sección de Resumen del Valor de Inventario
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Valor Total (Costo):',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${ref.read(inventoryProvider.notifier).totalInventoryValueVES.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // Lista de Productos (Manejando AsyncValue)
          Expanded(
            child: inventoryState.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Center(child: Text('El inventario está vacío. Agrega productos en la fila 2 de tu Google Sheets.'));
                }
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.inventory_2, color: Colors.white),
                      ),
                      title: Text(product.name),
                      subtitle: Text('Stock: ${product.stockQuantity} | P.V: \$${product.salePriceUSD}'),
                      trailing: Text(product.barCode),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: ${error.toString()}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductScreen()),
          );
        },
        tooltip: 'Agregar Producto',
        child: const Icon(Icons.add),
      ),
    );
  }
}

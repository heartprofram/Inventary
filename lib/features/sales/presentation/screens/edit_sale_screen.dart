import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/features/sales/domain/entities/payment.dart';
import '../../domain/sale.dart';
import '../../../../core/providers/core_providers.dart';
import 'package:inventary/features/inventory/presentation/providers/inventory_provider.dart';

class EditSaleScreen extends ConsumerStatefulWidget {
  final Sale sale;
  const EditSaleScreen({super.key, required this.sale});

  @override
  ConsumerState<EditSaleScreen> createState() => _EditSaleScreenState();
}

class _EditSaleScreenState extends ConsumerState<EditSaleScreen> {
  late List<SaleDetail> _details;
  late String _paymentMethod;

  @override
  void initState() {
    super.initState();
    _details = widget.sale.details.map((d) => SaleDetail(
      productId: d.productId,
      productName: d.productName,
      quantity: d.quantity,
      unitPriceUSD: d.unitPriceUSD,
    )).toList();
    
    _paymentMethod = widget.sale.payments.isNotEmpty ? widget.sale.payments.first.method : PaymentMethods.efectivoUsd;
  }

  double get _totalUSD => _details.fold(0.0, (sum, item) => sum + item.subtotalUSD);
  double get _totalVES => _totalUSD * widget.sale.exchangeRate;

  void _updateQuantity(int index, int delta) {
    setState(() {
      final item = _details[index];
      final newQuantity = item.quantity + delta;
      if (newQuantity <= 0) {
        _details.removeAt(index);
      } else {
        _details[index] = SaleDetail(
          productId: item.productId,
          productName: item.productName,
          quantity: newQuantity,
          unitPriceUSD: item.unitPriceUSD,
        );
      }
    });
  }

  void _saveChanges() async {
    if (_details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La venta no puede estar vacía. Usa Eliminar en el Historial.')));
      return;
    }

    final newSale = Sale(
      id: widget.sale.id,
      date: widget.sale.date,
      exchangeRate: widget.sale.exchangeRate,
      details: _details,
      payments: [Payment(method: _paymentMethod, amount: _totalUSD)],
    );
    newSale.overrideTotals(_totalUSD, _totalVES);

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final repo = ref.read(salesRepositoryProvider);
      await repo.updateSale(widget.sale, newSale);
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venta actualizada exitosamente')));
      Navigator.pop(context, true); 
    } catch (e) {
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Venta #${widget.sale.id}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChanges,
            tooltip: 'Guardar Cambios',
          )
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Modifica las cantidades de los productos en caso de devolución parcial o error. Si necesitas anularla por completo, usa el botón de Eliminar en la pantalla anterior.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.justify,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OutlinedButton.icon(
              onPressed: () => _showAddProductDialog(context),
              icon: const Icon(Icons.add_shopping_cart, color: Colors.teal),
              label: const Text('Agregar Otro Producto | Cambiar'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Colors.teal),
                foregroundColor: Colors.teal,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _details.length,
              itemBuilder: (context, index) {
                final item = _details[index];
                return ListTile(
                  title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('\$${item.unitPriceUSD.toStringAsFixed(2)} c/u'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.swap_horiz_outlined, color: Colors.blue),
                        onPressed: () => _showSwapProductDialog(context, index),
                        tooltip: 'Cambiar Producto',
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => _updateQuantity(index, -1),
                      ),
                      Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                        onPressed: () => _updateQuantity(index, 1),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Text('Método de pago: $_paymentMethod', style: const TextStyle(color: Colors.grey)),
                   const SizedBox(height: 8),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Original USD:', style: TextStyle(fontSize: 14)),
                      Text('\$${widget.sale.totalUSD.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('NUEVO TOTAL USD:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('\$${_totalUSD.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('NUEVO TOTAL VES:', style: TextStyle(fontSize: 16)),
                      Text('Bs. ${_totalVES.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _saveChanges,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar Cambios', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showSwapProductDialog(BuildContext context, int indexToReplace) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.5,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final inventoryAsync = ref.watch(inventoryProvider);
                return inventoryAsync.when(
                  data: (products) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Cambiar "${_details[indexToReplace].productName}" por:', 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final p = products[index];
                            return ListTile(
                              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.swap_horiz, size: 20, color: Colors.white)),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('\$${p.salePriceUSD} - Stock: ${p.stockQuantity}'),
                              onTap: () {
                                setState(() {
                                  final oldQuantity = _details[indexToReplace].quantity;
                                  final existingIdx = _details.indexWhere((d) => d.productId == p.id);
                                  
                                  if (existingIdx >= 0 && existingIdx != indexToReplace) {
                                    _updateQuantity(existingIdx, oldQuantity);
                                    _details.removeAt(indexToReplace);
                                  } else {
                                    _details[indexToReplace] = SaleDetail(
                                      productId: p.id,
                                      productName: p.name,
                                      quantity: oldQuantity,
                                      unitPriceUSD: p.salePriceUSD,
                                    );
                                  }
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddProductDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.5,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Consumer(
              builder: (context, ref, child) {
                final inventoryAsync = ref.watch(inventoryProvider);
                return inventoryAsync.when(
                  data: (products) => Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Seleccionar Producto de Reemplazo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final p = products[index];
                            return ListTile(
                              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.inventory_2, size: 20, color: Colors.white)),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('\$${p.salePriceUSD} - Stock: ${p.stockQuantity}'),
                              onTap: () {
                                setState(() {
                                  final existingIdx = _details.indexWhere((d) => d.productId == p.id);
                                  if (existingIdx >= 0) {
                                    _updateQuantity(existingIdx, 1);
                                  } else {
                                    _details.add(SaleDetail(
                                      productId: p.id,
                                      productName: p.name,
                                      quantity: 1,
                                      unitPriceUSD: p.salePriceUSD,
                                    ));
                                  }
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                );
              },
            );
          },
        );
      },
    );
  }
}
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import 'package:inventary/core/widgets/custom_snackbar.dart';
import 'package:inventary/features/sales/presentation/providers/payment_provider.dart';
import 'package:inventary/features/sales/domain/entities/payment.dart';
import 'package:inventary/features/sales/domain/sale.dart' hide Payment;
import 'package:inventary/features/sales/presentation/providers/cart_provider.dart';
import 'package:inventary/features/sales/presentation/providers/sales_providers.dart';
import 'package:inventary/features/settings/presentation/providers/settings_provider.dart';

final printInvoiceProvider = StateProvider<bool>((ref) => true);

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeRateState = ref.watch(exchangeRateProvider);
    final currentExchangeRate = exchangeRateState.value?.rate ?? 36.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;
        
        return Scaffold(
          body: isWide 
              ? Row(
                  children: [
                    Expanded(flex: 7, child: _buildProductSection(context, ref)),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 3, child: _buildCartPanel(context, ref, currentExchangeRate)),
                  ],
                )
              : _buildProductSection(context, ref),
          floatingActionButton: isWide ? null : _buildMobileCartFAB(context, ref),
        );
      },
    );
  }

  Widget _buildProductSection(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBar(
            onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
            hintText: 'Buscar productos...',
            leading: const Icon(Icons.search, color: Colors.teal),
            trailing: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.qr_code_scanner, color: Colors.teal)),
              if (ref.watch(searchQueryProvider).isNotEmpty)
                IconButton(
                  onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                  icon: const Icon(Icons.clear, color: Colors.grey),
                ),
            ],
            elevation: MaterialStateProperty.all(2),
            padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
            shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        Expanded(
          child: ref.watch(filteredInventoryProvider).when(
            data: (products) {
              if (products.isEmpty) {
                return EmptyState(
                  icon: Icons.search_off,
                  title: 'No se encontraron productos',
                  message: 'Prueba buscando con otro nombre o código de barras.',
                  onAction: () => ref.read(searchQueryProvider.notifier).state = '',
                  actionLabel: 'Ver todos',
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      onTap: () => ref.read(cartProvider.notifier).addProduct(product),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              color: Colors.teal.withOpacity(0.1),
                              child: const Icon(Icons.inventory, size: 48, color: Colors.teal),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text('Stock: ${product.stockQuantity}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('\$${product.salePriceUSD}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                                    const Icon(Icons.add_circle, color: Colors.teal),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const ShimmerGrid(),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildCartPanel(BuildContext context, WidgetRef ref, double currentExchangeRate) {
    final cartItems = ref.watch(cartProvider);
    final generateInvoice = ref.watch(printInvoiceProvider);

    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: Colors.teal),
                const SizedBox(width: 12),
                const Text('Carrito de Compras', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (cartItems.isNotEmpty)
                  IconButton(
                    onPressed: () => ref.read(cartProvider.notifier).clear(),
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    tooltip: 'Vaciar Carrito',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cartItems.isEmpty
                ? const EmptyState(icon: Icons.shopping_basket_outlined, title: 'Carrito vacío', message: 'Agrega productos para comenzar una venta.')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  Text('\$${item.subtotalUSD.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => ref.read(cartProvider.notifier).removeProduct(item.productId),
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.teal),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                                    child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      // Aquí iría la lógica de agregar uno más si el stock lo permite
                                      // Usaremos el provider de inventario para validar??
                                      // Por ahora solo una función simplificada
                                      _incrementQuantity(ref, item.productId);
                                    },
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _showEditPriceDialog(context, ref, item),
                                    icon: const Icon(Icons.edit_note),
                                    color: Colors.blueGrey,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    onPressed: () => ref.read(cartProvider.notifier).removeProduct(item.productId, removeAll: true),
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _buildCheckoutSummary(context, ref, currentExchangeRate, generateInvoice),
        ],
      ),
    );
  }

  void _incrementQuantity(WidgetRef ref, String productId) {
    // Buscar el producto en el inventario para validar stock
    final inventory = ref.read(filteredInventoryProvider).asData?.value ?? [];
    final originalProduct = inventory.firstWhere((p) => p.id == productId);
    
    // Contar cuántos hay en carrito
    final cart = ref.read(cartProvider);
    final cartItem = cart.firstWhere((i) => i.productId == productId);
    
    if (cartItem.quantity < originalProduct.stockQuantity) {
      ref.read(cartProvider.notifier).addProduct(originalProduct);
    }
  }

  Widget _buildCheckoutSummary(BuildContext context, WidgetRef ref, double currentExchangeRate, bool generateInvoice) {
    final totalUSD = ref.read(cartProvider.notifier).totalCartUSD;
    final totalVES = totalUSD * currentExchangeRate;
    final payments = ref.watch(paymentsProvider);
    final totalPaid = ref.watch(paymentsProvider.notifier).totalPaid;
    final isCartEmpty = totalUSD <= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL USD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
              Text('\$${totalUSD.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tasa: $currentExchangeRate VES', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              Text('Bs. ${totalVES.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          if (payments.isNotEmpty) ...[
             const Text('Pagos Registrados:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
             ...payments.map((p) => Padding(
               padding: const EdgeInsets.symmetric(vertical: 4),
               child: Row(
                 children: [
                   Icon(Icons.check_circle_outline, size: 14, color: Colors.green[700]),
                   const SizedBox(width: 8),
                   Expanded(child: Text(p.method, style: const TextStyle(fontSize: 13))),
                   Text('\$${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                   IconButton(
                     onPressed: () => ref.read(paymentsProvider.notifier).removePayment(p),
                     icon: const Icon(Icons.cancel, size: 14, color: Colors.grey),
                     padding: EdgeInsets.zero,
                     visualDensity: VisualDensity.compact,
                   ),
                 ],
               ),
             )),
             const Divider(),
          ],
          Row(
            children: [
              Checkbox(
                value: generateInvoice,
                onChanged: (v) => ref.read(printInvoiceProvider.notifier).state = v ?? true,
                activeColor: Colors.teal,
              ),
              const Text('Recibo PDF', style: TextStyle(fontSize: 14)),
              const Spacer(),
              TextButton.icon(
                onPressed: isCartEmpty ? null : () => _showAddPaymentDialog(context, ref),
                icon: const Icon(Icons.add_card),
                label: const Text('Agregar Pago'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isCartEmpty || (totalPaid != totalUSD) ? null : () => _processCheckout(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: Text(
              totalPaid < totalUSD ? 'FALTAN \$${(totalUSD - totalPaid).toStringAsFixed(2)}' : 'COBRAR \$${totalUSD.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCartFAB(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final totalItems = cartItems.fold(0, (sum, item) => sum + item.quantity);
    
    return FloatingActionButton.extended(
      onPressed: () => _showMobileCart(context, ref),
      backgroundColor: Colors.teal,
      icon: Badge(
        label: Text('$totalItems'),
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
      label: const Text('Carrito', style: TextStyle(color: Colors.white)),
    );
  }

  void _showMobileCart(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildCartPanel(context, ref, ref.read(exchangeRateProvider).value?.rate ?? 36.0),
        ),
      ),
    );
  }

  Future<void> _processCheckout(BuildContext context, WidgetRef ref) async {
    final generateInvoice = ref.read(printInvoiceProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(checkoutProvider.notifier).processCheckout(printInvoice: generateInvoice);
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        CustomSnackBar.success(context, 'Transacción completada exitosamente.');
        if (!kIsWeb && Navigator.canPop(context)) Navigator.pop(context); // Close mobile sheet
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        CustomSnackBar.error(context, 'Error al procesar: $e');
      }
    }
  }

  void _showAddPaymentDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    // Sugerir el monto faltante
    final totalUSD = ref.read(cartProvider.notifier).totalCartUSD;
    final totalPaid = ref.read(paymentsProvider.notifier).totalPaid;
    amountController.text = (totalUSD - totalPaid).toString();
    
    String selectedMethod = PaymentMethods.efectivoUsd;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedMethod,
              items: PaymentMethods.labels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: (v) => selectedMethod = v!,
              decoration: const InputDecoration(labelText: 'Método'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto USD', prefixText: '\$'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                if (selectedMethod == PaymentMethods.pendiente) {
                  _showDebtorNameDialog(context, ref, amount);
                } else {
                  ref.read(paymentsProvider.notifier).addPayment(Payment(method: selectedMethod, amount: amount));
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showDebtorNameDialog(BuildContext context, WidgetRef ref, double amount) {
    final debtorNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos del Deudor'),
        content: TextField(
          controller: debtorNameController,
          decoration: const InputDecoration(labelText: 'Nombre Completo'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final name = debtorNameController.text;
              if (name.isNotEmpty) {
                ref.read(debtorNameProvider.notifier).state = name;
                ref.read(paymentsProvider.notifier).addPayment(Payment(method: PaymentMethods.pendiente, amount: amount));
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditPriceDialog(BuildContext context, WidgetRef ref, dynamic item) {
    final controller = TextEditingController(text: item.unitPriceUSD.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar precio: ${item.productName}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Precio USD', prefixText: '\$'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price >= 0) {
                ref.read(cartProvider.notifier).editProductPrice(item.productId, price);
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
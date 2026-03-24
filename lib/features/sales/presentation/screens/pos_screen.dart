import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import 'package:inventary/core/widgets/custom_snackbar.dart';
import 'package:inventary/features/sales/presentation/providers/payment_provider.dart';
import 'package:inventary/features/sales/domain/entities/payment.dart';
import 'package:inventary/features/sales/domain/sale.dart';
import 'package:inventary/features/sales/presentation/providers/cart_provider.dart';
import 'package:inventary/features/sales/presentation/providers/sales_providers.dart';
import 'package:inventary/features/settings/presentation/providers/settings_provider.dart';

final printInvoiceProvider = StateProvider<bool>((ref) => false);
final debtorNameProvider = StateProvider<String>((ref) => '');

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
                    Expanded(
                      flex: 7,
                      child: _buildProductSection(context, ref),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 3,
                      child: _buildCartPanel(context, ref, currentExchangeRate),
                    ),
                  ],
                )
              : _buildProductSection(context, ref),
          floatingActionButton: isWide
              ? null
              : _buildMobileCartFAB(context, ref),
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
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).state = value,
            hintText: 'Buscar productos...',
            leading: const Icon(Icons.search, color: Colors.teal),
            trailing: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.qr_code_scanner, color: Colors.teal),
              ),
              if (ref.watch(searchQueryProvider).isNotEmpty)
                IconButton(
                  onPressed: () =>
                      ref.read(searchQueryProvider.notifier).state = '',
                  icon: const Icon(Icons.clear, color: Colors.grey),
                ),
            ],
            elevation: WidgetStateProperty.all(2),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: ref
              .watch(filteredInventoryProvider)
              .when(
                data: (products) {
                  if (products.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off,
                      title: 'No se encontraron productos',
                      message:
                          'Prueba buscando con otro nombre o código de barras.',
                      onAction: () =>
                          ref.read(searchQueryProvider.notifier).state = '',
                      actionLabel: 'Ver todos',
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () => ref
                              .read(cartProvider.notifier)
                              .addProduct(product),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Container(
                                  color: Colors.teal.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.inventory,
                                    size: 48,
                                    color: Colors.teal,
                                  ),
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Stock: ${product.stockQuantity}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '\$${product.salePriceUSD}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.add_circle,
                                          color: Colors.teal,
                                        ),
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

  Widget _buildCartPanel(
    BuildContext context,
    WidgetRef ref,
    double currentExchangeRate,
  ) {
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
                const Text(
                  'Carrito de Compras',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (cartItems.isNotEmpty)
                  IconButton(
                    onPressed: () => ref.read(cartProvider.notifier).clear(),
                    icon: const Icon(
                      Icons.delete_sweep,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Vaciar Carrito',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cartItems.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_basket_outlined,
                    title: 'Carrito vacío',
                    message: 'Agrega productos para comenzar una venta.',
                  )
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
                                    child: Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\$${item.subtotalUSD.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => ref
                                        .read(cartProvider.notifier)
                                        .removeProduct(item.productId),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _incrementQuantity(ref, item.productId);
                                    },
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _showEditPriceDialog(
                                      context,
                                      ref,
                                      item,
                                    ),
                                    icon: const Icon(Icons.edit_note),
                                    color: Colors.blueGrey,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    onPressed: () => ref
                                        .read(cartProvider.notifier)
                                        .removeProduct(
                                          item.productId,
                                          removeAll: true,
                                        ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                    ),
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
          _buildCheckoutSummary(
            context,
            ref,
            currentExchangeRate,
            generateInvoice,
          ),
        ],
      ),
    );
  }

  void _incrementQuantity(WidgetRef ref, String productId) {
    final inventory = ref.read(filteredInventoryProvider).asData?.value ?? [];
    final originalProduct = inventory.firstWhere((p) => p.id == productId);
    final cart = ref.read(cartProvider);
    final cartItem = cart.firstWhere((i) => i.productId == productId);

    if (cartItem.quantity < originalProduct.stockQuantity) {
      ref.read(cartProvider.notifier).addProduct(originalProduct);
    }
  }

  Widget _buildCheckoutSummary(
    BuildContext context,
    WidgetRef ref,
    double currentExchangeRate,
    bool generateInvoice,
  ) {
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
              const Text(
                'TOTAL USD',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              Text(
                '\$${totalUSD.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tasa: $currentExchangeRate VES',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              Text(
                'Bs. ${totalVES.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (payments.isNotEmpty) ...[
            const Text(
              'Pagos Registrados:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            ...payments.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.method,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '\$${p.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          ref.read(paymentsProvider.notifier).removePayment(p),
                      icon: const Icon(
                        Icons.cancel,
                        size: 14,
                        color: Colors.grey,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
          ],
          Row(
            children: [
              Checkbox(
                value: generateInvoice,
                onChanged: (v) =>
                    ref.read(printInvoiceProvider.notifier).state = v ?? true,
                activeColor: Colors.teal,
              ),
              const Text(
                'Generar Recibo (PDF)',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (payments.isNotEmpty) ...[
            TextButton.icon(
              onPressed: () =>
                  ref.read(paymentsProvider.notifier).clearPayments(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reiniciar pagos para cobro rápido'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
          ],

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: [
              _QuickPaymentButton(
                label: 'EFECTIVO \$',
                icon: Icons.attach_money,
                color: Colors.green,
                onPressed: isCartEmpty
                    ? null
                    : () => _processDirectPayment(context, ref, 'Efectivo USD'),
              ),
              _QuickPaymentButton(
                label: 'PAGO MÓVIL',
                icon: Icons.phone_android,
                color: Colors.blue,
                onPressed: isCartEmpty
                    ? null
                    : () => _processDirectPayment(context, ref, 'Pago Movil'),
              ),
              _QuickPaymentButton(
                label: 'PUNTO',
                icon: Icons.credit_card,
                color: Colors.teal,
                onPressed: isCartEmpty
                    ? null
                    : () =>
                          _processDirectPayment(context, ref, 'Punto de Venta'),
              ),
              _QuickPaymentButton(
                label: 'FIADO (PEND.)',
                icon: Icons.person_add_alt,
                color: Colors.orange,
                onPressed: isCartEmpty
                    ? null
                    : () => _showQuickDebtorDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _QuickPaymentButton(
            label: 'PAGO MIXTO / OTROS',
            icon: Icons.payments_outlined,
            color: Colors.blueGrey,
            isFullWidth: true,
            onPressed: isCartEmpty
                ? null
                : () => _showAddPaymentDialog(context, ref),
          ),

          if (payments.isNotEmpty && totalPaid == totalUSD) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _processCheckout(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'CONFIRMAR VENTA FINAL',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _processDirectPayment(
    BuildContext context,
    WidgetRef ref,
    String method,
  ) async {
    final totalUSD = ref.read(cartProvider.notifier).totalCartUSD;
    ref.read(paymentsProvider.notifier).clearPayments();
    ref
        .read(paymentsProvider.notifier)
        .addPayment(Payment(method: method, amount: totalUSD));
    await _processCheckout(context, ref);
  }

  void _showQuickDebtorDialog(BuildContext screenContext, WidgetRef ref) {
    String debtorName = '';
    showDialog(
      context: screenContext,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Nombre del Deudor'),
        content: TextField(
          onChanged: (v) => debtorName = v,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cliente',
            hintText: 'Ej. Juan Pérez',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (debtorName.trim().isNotEmpty) {
                final totalUSD = ref.read(cartProvider.notifier).totalCartUSD;
                ref.read(debtorNameProvider.notifier).state = debtorName;
                ref.read(paymentsProvider.notifier).clearPayments();
                ref
                    .read(paymentsProvider.notifier)
                    .addPayment(Payment(method: 'Pendiente', amount: totalUSD));
                Navigator.pop(dialogCtx);
                _processCheckout(screenContext, ref);
              } else {
                CustomSnackBar.warning(
                  dialogCtx,
                  'El nombre es obligatorio para fiar.',
                );
              }
            },
            child: const Text('Registrar Deuda'),
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
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (builderCtx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildCartPanel(
            builderCtx,
            ref,
            ref.read(exchangeRateProvider).value?.rate ?? 36.0,
          ),
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
      await ref
          .read(checkoutProvider.notifier)
          .processCheckout(printInvoice: generateInvoice);
      if (context.mounted) {
        Navigator.pop(context);
        CustomSnackBar.success(context, 'Transacción completada exitosamente.');
        if (!kIsWeb && Navigator.canPop(context)) Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        CustomSnackBar.error(context, 'Error al procesar: $e');
      }
    }
  }

  void _showAddPaymentDialog(BuildContext screenContext, WidgetRef ref) {
    final totalUSD = ref.read(cartProvider.notifier).totalCartUSD;
    final totalPaid = ref.read(paymentsProvider.notifier).totalPaid;
    final remainingUSD = totalUSD - totalPaid;

    if (remainingUSD <= 0) return;

    showDialog(
      context: screenContext,
      builder: (dialogCtx) {
        String? debtorName;
        bool isPending = false;

        return StatefulBuilder(
          builder: (stateCtx, setState) {
            return AlertDialog(
              title: const Text(
                'Método de Pago',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Monto a cobrar: \$${remainingUSD.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _PaymentTypeButton(
                        label: 'Efectivo \$',
                        icon: Icons.attach_money,
                        color: Colors.green,
                        onTap: () {
                          ref
                              .read(paymentsProvider.notifier)
                              .addPayment(
                                Payment(
                                  method: 'Efectivo USD',
                                  amount: remainingUSD,
                                ),
                              );
                          Navigator.pop(dialogCtx);
                        },
                      ),
                      _PaymentTypeButton(
                        label: 'Pago Móvil',
                        icon: Icons.phone_android,
                        color: Colors.blue,
                        onTap: () {
                          ref
                              .read(paymentsProvider.notifier)
                              .addPayment(
                                Payment(
                                  method: 'Pago Movil',
                                  amount: remainingUSD,
                                ),
                              );
                          Navigator.pop(dialogCtx);
                        },
                      ),
                      _PaymentTypeButton(
                        label: 'Punto',
                        icon: Icons.credit_card,
                        color: Colors.orange,
                        onTap: () {
                          ref
                              .read(paymentsProvider.notifier)
                              .addPayment(
                                Payment(
                                  method: 'Punto de Venta',
                                  amount: remainingUSD,
                                ),
                              );
                          Navigator.pop(dialogCtx);
                        },
                      ),
                      _PaymentTypeButton(
                        label: 'Pendiente',
                        icon: Icons.person_add_alt,
                        color: Colors.redAccent,
                        isOutline: !isPending,
                        onTap: () {
                          setState(() {
                            isPending = true;
                          });
                        },
                      ),
                    ],
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 20),
                    TextField(
                      onChanged: (v) => debtorName = v,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Cliente (Deudor)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                        fillColor: Colors.red.withOpacity(0.05),
                        filled: true,
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          if (debtorName != null &&
                              debtorName!.trim().isNotEmpty) {
                            ref.read(debtorNameProvider.notifier).state =
                                debtorName!;
                            ref
                                .read(paymentsProvider.notifier)
                                .addPayment(
                                  Payment(
                                    method: 'Pendiente',
                                    amount: remainingUSD,
                                  ),
                                );
                            Navigator.pop(dialogCtx);
                          } else {
                            CustomSnackBar.warning(
                              stateCtx,
                              'El nombre del deudor es obligatorio.',
                            );
                          }
                        },
                        child: const Text(
                          'Confirmar Deuda',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditPriceDialog(BuildContext context, WidgetRef ref, dynamic item) {
    final controller = TextEditingController(
      text: item.unitPriceUSD.toString(),
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Editar precio: ${item.productName}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Precio USD',
            prefixText: '\$',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null && price >= 0) {
                ref
                    .read(cartProvider.notifier)
                    .editProductPrice(item.productId, price);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _QuickPaymentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isFullWidth;

  const _QuickPaymentButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }
}

class _PaymentTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isOutline;

  const _PaymentTypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isOutline = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 90,
      child: Material(
        color: isOutline ? Colors.transparent : color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color, width: isOutline ? 1 : 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/features/sales/presentation/providers/payment_provider.dart';
import 'package:inventary/features/sales/domain/models/payment.dart';
import 'package:inventary/features/sales/presentation/providers/cart_provider.dart';
import 'package:inventary/features/sales/presentation/providers/sales_providers.dart';
import 'package:inventary/features/settings/presentation/providers/settings_provider.dart';

// Provider local para controlar la generación de factura
final printInvoiceProvider = StateProvider<bool>((ref) => true);

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final exchangeRateState = ref.watch(exchangeRateProvider);
    final generateInvoice = ref.watch(printInvoiceProvider);

    final currentExchangeRate = exchangeRateState.value?.rate ?? 36.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Punto de Venta (POS)')),
      // Usamos LayoutBuilder para pantalla dividida adaptativa
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;
          final layoutChildren = [
            // PANEL IZQUIERDO: PRODUCTOS CON STOCK (+)
            Expanded(
              flex: isMobile ? 5 : 2,
              child: Column(
                children: [
                  // BARRA DE BÚSQUEDA
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      onChanged: (value) =>
                          ref.read(searchQueryProvider.notifier).state = value,
                      decoration: InputDecoration(
                        hintText: 'Buscar productos...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.teal,
                        ),
                        suffixIcon: ref.watch(searchQueryProvider).isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  ref.read(searchQueryProvider.notifier).state =
                                      '';
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.teal,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),

                  // LISTA DE PRODUCTOS FILTRADOS
                  Expanded(
                    child: ref
                        .watch(filteredInventoryProvider)
                        .when(
                          data: (products) {
                            if (products.isEmpty) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No se encontraron productos.',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(8.0),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.65, // Reducido para evitar overflow
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return Card(
                                  elevation: 3,
                                  child: InkWell(
                                    onTap: () {
                                      // Agregar al carrito
                                      ref
                                          .read(cartProvider.notifier)
                                          .addProduct(product);
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.inventory,
                                          size: 40,
                                          color: Colors.teal,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          product.name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text('Stock: ${product.stockQuantity}'),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${product.salePriceUSD}',
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, stack) =>
                              Center(child: Text('Error: $err')),
                        ),
                  ),
                ],
              ),
            ),

            // PANEL DERECHO: CARRITO Y TICKET
            Expanded(
              flex: isMobile ? 6 : 1,
              child: Container(
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    // Título de carrito
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.grey.shade300,
                      width: double.infinity,
                      child: const Text(
                        'Carrito Actual',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Lista de items del carrito
                    Expanded(
                      child: cartState.isEmpty
                          ? const Center(child: Text('El carrito esta vacio.'))
                          : ListView.builder(
                              itemCount: cartState.length,
                              itemBuilder: (context, index) {
                                final item = cartState[index];
                                return ListTile(
                                  title: Text(item.productName),
                                  subtitle: Text(
                                    '\$${item.unitPriceUSD.toStringAsFixed(2)} x ${item.quantity}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _showEditPriceDialog(
                                            context,
                                            ref,
                                            item,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(cartProvider.notifier)
                                              .removeProduct(item.productId);
                                        },
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          '\$${item.subtotalUSD.toStringAsFixed(2)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Área de Totales, Método de Pago y Botón Cobrar
                    Flexible(
                      child: SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL USD:',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '\$${ref.read(cartProvider.notifier).totalCartUSD.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              // Mostrar el equivalente en VES usando la Tasa de Cambio
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Tasa: $currentExchangeRate VES/USD',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    'Bs. ${(ref.read(cartProvider.notifier).totalCartUSD * currentExchangeRate).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // ─── PAGOS ───
                              const Text(
                                'Pagos:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...ref.watch(paymentsProvider).map((payment) => ListTile(
                                    title: Text(payment.method),
                                    trailing: Text('\$${payment.amount.toStringAsFixed(2)}'),
                                    onTap: () {
                                      ref.read(paymentsProvider.notifier).removePayment(payment);
                                    },
                                  )),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showAddPaymentDialog(context, ref),
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar Pago'),
                              ),
                              const SizedBox(height: 12),

                              // -- CHECKBOX FACTURA --
                              Row(
                                children: [
                                  Checkbox(
                                    value: generateInvoice,
                                    onChanged: (value) {
                                      ref
                                              .read(
                                                printInvoiceProvider.notifier,
                                              )
                                              .state =
                                          value ?? true;
                                    },
                                    activeColor: Colors.teal,
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Generar y descargar factura PDF',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                ),
                                onPressed: cartState.isEmpty || ref.watch(paymentsProvider.notifier).totalPaid != ref.watch(cartProvider.notifier).totalCartUSD
                                    ? null
                                    : () async {
                                        // Mostrar un loading local o dialog
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );

                                        try {
                                          await ref
                                              .read(checkoutProvider.notifier)
                                              .processCheckout(
                                                printInvoice: generateInvoice,
                                              );

                                          if (context.mounted) {
                                            Navigator.pop(
                                              context,
                                            ); // Cerrar loading
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Venta Procesada. Factura generada.',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            Navigator.pop(
                                              context,
                                            ); // Cerrar loading
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error al procesar: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                child: const Text(
                                  'PROCESAR VENTA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
          return isMobile
              ? Column(children: layoutChildren)
              : Row(children: layoutChildren);
        },
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    String selectedMethod = PaymentMethods.efectivoUsd;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Pago'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedMethod,
                items: PaymentMethods.labels.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedMethod = value;
                  }
                },
                decoration: const InputDecoration(labelText: 'Método de Pago'),
              ),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto USD',
                  prefixText: '\$',
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
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  if (selectedMethod == PaymentMethods.pendiente) {
                    _showDebtorNameDialog(context, ref, amount);
                  } else {
                    ref.read(paymentsProvider.notifier).addPayment(
                          Payment(method: selectedMethod, amount: amount),
                        );
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _showDebtorNameDialog(BuildContext context, WidgetRef ref, double amount) {
    final debtorNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pago Pendiente'),
          content: TextField(
            controller: debtorNameController,
            decoration: const InputDecoration(labelText: 'Nombre del Deudor'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final debtorName = debtorNameController.text;
                if (debtorName.isNotEmpty) {
                  ref.read(debtorNameProvider.notifier).state = debtorName;
                  ref.read(paymentsProvider.notifier).addPayment(
                        Payment(method: PaymentMethods.pendiente, amount: amount),
                      );
                }
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
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
      builder: (context) {
        return AlertDialog(
          title: Text('Editar precio de ${item.productName}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Nuevo precio USD',
              prefixText: '\$',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final newPrice = double.tryParse(controller.text);
                if (newPrice != null && newPrice >= 0) {
                  ref
                      .read(cartProvider.notifier)
                      .editProductPrice(item.productId, newPrice);
                }
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

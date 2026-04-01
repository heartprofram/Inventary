import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ─── IMPORTACIONES ABSOLUTAS (SOLUCIÓN AL ERROR) ───
import 'package:inventary/core/providers/core_providers.dart'; // <-- ¡Aquí está el que faltaba!
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import 'package:inventary/core/widgets/custom_snackbar.dart';

import 'package:inventary/features/sales/presentation/providers/sales_providers.dart';
import 'package:inventary/features/sales/presentation/providers/pending_payments_provider.dart';
import 'package:inventary/features/sales/domain/entities/payment.dart';
import 'package:inventary/features/sales/domain/sale.dart';
import 'package:inventary/features/settings/presentation/providers/settings_provider.dart';
import 'package:inventary/features/reports/presentation/providers/reports_provider.dart';

class PendingPaymentsScreen extends ConsumerStatefulWidget {
  const PendingPaymentsScreen({super.key});

  @override
  ConsumerState<PendingPaymentsScreen> createState() =>
      _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends ConsumerState<PendingPaymentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingPaymentsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingPaymentsProvider);
    final exchangeRateAsync = ref.watch(exchangeRateProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Cuentas por Cobrar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 0,
      ),
      body: pendingAsync.when(
        data: (pendings) {
          // Filtramos para asegurarnos de no mostrar deudas que ya están en cero
          final activePendings = pendings
              .where((p) => p.deudaTotalUsd > 0.01)
              .toList();

          if (activePendings.isEmpty) {
            return EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Cuentas al día',
              message:
                  'No hay deudas o pagos pendientes registrados actualmente.',
              onAction: () =>
                  ref.read(pendingPaymentsProvider.notifier).refresh(),
              actionLabel: 'Actualizar',
            );
          }

          final currentRate = exchangeRateAsync.value?.rate ?? 36.0;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activePendings.length,
            itemBuilder: (context, index) {
              final pending = activePendings[index];
              final totalVes = pending.deudaTotalUsd * currentRate;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.teal.withOpacity(0.1),
                            child: const Icon(Icons.person, color: Colors.teal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pending.deudor.trim().isNotEmpty
                                      ? pending.deudor
                                      : "Cliente Anónimo",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  pending.fecha,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${pending.deudaTotalUsd.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: Colors.redAccent,
                                ),
                              ),
                              Text(
                                'Bs. ${totalVes.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${pending.detallesProductos.length} productos',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Eliminar deuda',
                                onPressed: () => _showDeleteConfirmation(
                                  context,
                                  ref,
                                  pending,
                                  currentRate,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showPaymentModal(
                                  context,
                                  ref,
                                  pending,
                                  currentRate,
                                ),
                                icon: const Icon(
                                  Icons.payments_outlined,
                                  size: 18,
                                ),
                                label: const Text('PROCESAR PAGO'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const ShimmerList(itemCount: 6),
        error: (err, stack) => EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          message: err.toString(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showManualDebtDialog(context),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: const Text('Registrar Deuda'),
      ),
    );
  }

  void _showManualDebtDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ManualDebtDialog(),
    );
  }

  void _showPaymentModal(
    BuildContext context,
    WidgetRef ref,
    PendingPayment pending,
    double rate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _MixedDebtPaymentDialog(pending: pending, rate: rate),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    PendingPayment pending,
    double rate,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar Deuda'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta cuenta por cobrar?\n\nEsta acción no se puede deshacer y devolverá los productos al inventario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
              try {
                final sale = pending.toSale(rate);
                await ref.read(salesRepositoryProvider).deleteSale(sale);
                ref.invalidate(pendingPaymentsProvider);
                if (context.mounted) {
                  CustomSnackBar.success(
                    context,
                    'Deuda eliminada exitosamente.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  CustomSnackBar.error(context, 'Error al eliminar: $e');
                }
              } finally {
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
  }
}

class ManualDebtDialog extends ConsumerStatefulWidget {
  const ManualDebtDialog({super.key});

  @override
  ConsumerState<ManualDebtDialog> createState() => _ManualDebtDialogState();
}

class _ManualDebtDialogState extends ConsumerState<ManualDebtDialog> {
  final _customerController = TextEditingController();
  final _conceptController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _customerController.dispose();
    _conceptController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.history_edu, color: Colors.teal),
          SizedBox(width: 12),
          Text('Gasto/Deuda Antigua'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customerController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Cliente',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _conceptController,
              decoration: const InputDecoration(
                labelText: 'Concepto (ej. Mercancía fiada)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto Total (USD)',
                prefixIcon: Icon(Icons.attach_money),
                prefixText: '\$',
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, color: Colors.teal),
              title: const Text(
                'Fecha de la Deuda',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                DateFormat('dd / MM / yyyy').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.teal,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveDebt,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _saveDebt() async {
    final customer = _customerController.text.trim();
    final concept = _conceptController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (customer.isEmpty || concept.isEmpty || amount == null || amount <= 0) {
      CustomSnackBar.warning(
        context,
        'Por favor complete todos los campos correctamente.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final exchangeRate = ref.read(exchangeRateProvider).value?.rate ?? 36.0;

      final newSale = Sale(
        id: 'VEN-MANUAL-${DateTime.now().millisecondsSinceEpoch}',
        date: _selectedDate,
        exchangeRate: exchangeRate,
        details: [
          SaleDetail(
            productId: 'DEUDA_MANUAL',
            productName: concept,
            quantity: 1,
            unitPriceUSD: amount,
          ),
        ],
        payments: [Payment(method: PaymentMethods.pendiente, amount: amount)],
        debtorName: customer,
      );

      await ref.read(salesRepositoryProvider).processSale(newSale);

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(pendingPaymentsProvider);
        CustomSnackBar.success(context, 'Deuda manual registrada con éxito.');
      }
    } catch (e) {
      if (mounted)
        CustomSnackBar.error(context, 'Error al registrar deuda: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// MODAL DE ABONOS CON AUTOCOMPLETADO
// ══════════════════════════════════════════════════════════════════════════
class _MixedDebtPaymentDialog extends ConsumerStatefulWidget {
  final PendingPayment pending;
  final double rate;

  const _MixedDebtPaymentDialog({required this.pending, required this.rate});

  @override
  ConsumerState<_MixedDebtPaymentDialog> createState() =>
      _MixedDebtPaymentDialogState();
}

class _MixedDebtPaymentDialogState
    extends ConsumerState<_MixedDebtPaymentDialog> {
  final Map<String, TextEditingController> _controllers = {};
  late double _remainingUSD;

  @override
  void initState() {
    super.initState();
    _remainingUSD = widget.pending.deudaTotalUsd;

    final methods = [
      PaymentMethods.efectivoUsd,
      PaymentMethods.efectivoVes,
      PaymentMethods.pagoMovil,
      PaymentMethods.puntoDeVenta,
    ];
    for (var m in methods) {
      _controllers[m] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isBolivaresMethod(String method) {
    return [
      PaymentMethods.efectivoVes,
      PaymentMethods.pagoMovil,
      PaymentMethods.puntoDeVenta,
    ].contains(method);
  }

  double _calculateInputUSD() {
    double total = 0.0;
    _controllers.forEach((method, controller) {
      final val = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
      if (val > 0) {
        total += _isBolivaresMethod(method) ? val / widget.rate : val;
      }
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final inputUSD = _calculateInputUSD();
    final missingUSD = _remainingUSD - inputUSD;
    final isCovered = missingUSD <= 0.01;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Abonar Cuenta',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCovered
                  ? Colors.green.withOpacity(0.05)
                  : Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCovered
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  isCovered ? 'Abono Completo' : 'Falta por Cobrar',
                  style: TextStyle(
                    color: isCovered ? Colors.green : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${missingUSD > 0 ? missingUSD.toStringAsFixed(2) : "0.00"}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isCovered ? Colors.green : Colors.redAccent,
                  ),
                ),
                if (missingUSD > 0)
                  Text(
                    'Bs. ${(missingUSD * widget.rate).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ..._controllers.entries.map((entry) {
            final method = entry.key;
            final isBs = _isBolivaresMethod(method);
            final controller = entry.value;

            IconData getIcon(String method) {
              if (method == PaymentMethods.efectivoUsd)
                return Icons.attach_money;
              if (method == PaymentMethods.efectivoVes) return Icons.money;
              if (method == PaymentMethods.pagoMovil)
                return Icons.phone_android;
              return Icons.credit_card;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText:
                      PaymentMethods.label(method) + (isBs ? ' (Bs)' : ' (\$)'),
                  prefixIcon: Icon(getIcon(method), color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  suffixIcon: missingUSD > 0.001
                      ? IconButton(
                          icon: const Icon(Icons.flash_on, color: Colors.amber),
                          tooltip: 'Autocompletar el resto',
                          onPressed: () {
                            final currentVal =
                                double.tryParse(
                                  controller.text.replaceAll(',', '.'),
                                ) ??
                                0.0;
                            final addition = isBs
                                ? (missingUSD * widget.rate)
                                : missingUSD;
                            controller.text = (currentVal + addition)
                                .toStringAsFixed(2);
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: inputUSD > 0.001
                ? () => _confirmPayment(context, inputUSD)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isCovered ? Colors.green : Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isCovered ? 'LIQUIDAR DEUDA' : 'CONFIRMAR ABONO PARCIAL',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmPayment(BuildContext context, double totalAbonadoUsd) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      // 1. Extraemos los pagos viejos que YA se habían hecho en esta factura
      final oldPayments = widget.pending.pagosPrevios
          .where((p) => p.method != PaymentMethods.pendiente)
          .toList();

      // 2. Extraemos los pagos NUEVOS de los textfields
      List<Payment> newPayments = [];
      _controllers.forEach((method, controller) {
        final val = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
        if (val > 0) {
          final usdVal = _isBolivaresMethod(method) ? val / widget.rate : val;
          newPayments.add(Payment(method: method, amount: usdVal));
        }
      });

      // 3. Calculamos lo que quedó pendiente AHORA
      List<Payment> finalPayments = [...oldPayments, ...newPayments];
      final newRemaining = _remainingUSD - totalAbonadoUsd;

      if (newRemaining > 0.01) {
        finalPayments.add(
          Payment(method: PaymentMethods.pendiente, amount: newRemaining),
        );
      }

      await ref
          .read(pendingPaymentsProvider.notifier)
          .updatePendingStatus(widget.pending.idVenta, finalPayments);

      ref.invalidate(salesHistoryProvider);
      ref.invalidate(reportsProvider);
      ref.invalidate(pendingPaymentsProvider);

      if (context.mounted) {
        Navigator.pop(context); // loading
        Navigator.pop(context); // modal
        CustomSnackBar.success(
          context,
          newRemaining <= 0.01
              ? 'Deuda liquidada'
              : 'Abono procesado exitosamente.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        CustomSnackBar.error(context, 'Error al procesar: $e');
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import 'package:inventary/core/widgets/custom_snackbar.dart';
import 'package:inventary/core/providers/core_providers.dart';
import 'package:intl/intl.dart';
import '../providers/sales_providers.dart';
import '../providers/pending_payments_provider.dart';
import '../../domain/entities/payment.dart';
import '../../domain/sale.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class PendingPaymentsScreen extends ConsumerStatefulWidget {
  const PendingPaymentsScreen({super.key});

  @override
  ConsumerState<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
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
        title: const Text('Cuentas por Cobrar', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 0,
      ),
      body: pendingAsync.when(
        data: (pendings) {
          if (pendings.isEmpty) {
            return EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Cuentas al día',
              message: 'No hay deudas o pagos pendientes registrados actualmente.',
              onAction: () => ref.read(pendingPaymentsProvider.notifier).refresh(),
              actionLabel: 'Actualizar',
            );
          }

          final currentRate = exchangeRateAsync.value?.rate ?? 36.0;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendings.length,
            itemBuilder: (context, index) {
              final pending = pendings[index];
              final totalVes = pending.totalUsd * currentRate;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                  pending.deudor,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  pending.fecha,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${pending.totalUsd.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.redAccent),
                              ),
                              Text(
                                'Bs. ${totalVes.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
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
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showPaymentModal(context, ref, pending, currentRate),
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('PROCESAR PAGO'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
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
        error: (err, stack) => EmptyState(icon: Icons.error_outline, title: 'Error', message: err.toString()),
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

  void _showPaymentModal(BuildContext context, WidgetRef ref, PendingPayment pending, double rate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confirmar Cobro',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Resumen de Productos:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView(
                shrinkWrap: true,
                children: pending.detallesProductos.map((det) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text('${det['cantidad']}x ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(det['nombre_producto'])),
                      Text('\$${(det['precio_unitario_usd'] * det['cantidad']).toStringAsFixed(2)}'),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL A PAGAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${pending.totalUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.green)),
                    Text('Bs. ${(pending.totalUsd * rate).toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Seleccione Medio de Pago:', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _PaymentMethodChip(
                  label: 'Efectivo \$',
                  icon: Icons.attach_money,
                  color: Colors.green,
                  onTap: () => _confirmFinalPayment(context, ref, pending, 'efectivo_usd'),
                ),
                _PaymentMethodChip(
                  label: 'Pago Móvil',
                  icon: Icons.phone_android,
                  color: Colors.blue,
                  onTap: () => _confirmFinalPayment(context, ref, pending, 'pago_movil'),
                ),
                _PaymentMethodChip(
                  label: 'Punto',
                  icon: Icons.credit_card,
                  color: Colors.orange,
                  onTap: () => _confirmFinalPayment(context, ref, pending, 'punto_de_venta'),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  void _confirmFinalPayment(BuildContext context, WidgetRef ref, PendingPayment pending, String method) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final payments = [Payment(method: method, amount: pending.totalUsd)];
      await ref.read(pendingPaymentsProvider.notifier).updatePendingStatus(pending.idVenta, payments);
      if (context.mounted) {
        Navigator.pop(context); // close loading
        Navigator.pop(context); // close modal
        CustomSnackBar.success(context, 'Pago procesado exitosamente.');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        CustomSnackBar.error(context, 'Error al procesar el pago: $e');
      }
    }
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              title: const Text('Fecha de la Deuda', style: TextStyle(fontSize: 14)),
              subtitle: Text(DateFormat('dd / MM / yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.teal)),
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveDebt,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          child: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
      CustomSnackBar.warning(context, 'Por favor complete todos los campos correctamente.');
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
      if (mounted) CustomSnackBar.error(context, 'Error al registrar deuda: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

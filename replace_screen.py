import sys

file_path = "lib/features/sales/presentation/screens/pending_payments_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

content = "".join(lines)
content = content.replace("final totalVes = pending.totalUsd * currentRate;", "final totalVes = pending.deudaTotalUsd * currentRate;")
content = content.replace("Text('\\\\$${pending.totalUsd.toStringAsFixed(2)}'", "Text('\\\\$${pending.deudaTotalUsd.toStringAsFixed(2)}'")

# Replace _showPaymentModal and _confirmFinalPayment and _PaymentMethodChip
new_dialog_code = """  void _showPaymentModal(BuildContext context, WidgetRef ref, PendingPayment pending, double rate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MixedDebtPaymentDialog(pending: pending, rate: rate),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, PendingPayment pending, double rate) {
"""

# Replace block from _showPaymentModal up to _showDeleteConfirmation
start_idx = content.find("  void _showPaymentModal(")
end_idx = content.find("  void _showDeleteConfirmation(")

if start_idx != -1 and end_idx != -1:
    content = content[:start_idx] + new_dialog_code + content[end_idx:]

chip_idx = content.find("class _PaymentMethodChip extends StatelessWidget {")
if chip_idx != -1:
    dialog_impl = """
class _MixedDebtPaymentDialog extends ConsumerStatefulWidget {
  final PendingPayment pending;
  final double rate;

  const _MixedDebtPaymentDialog({required this.pending, required this.rate});

  @override
  ConsumerState<_MixedDebtPaymentDialog> createState() => _MixedDebtPaymentDialogState();
}

class _MixedDebtPaymentDialogState extends ConsumerState<_MixedDebtPaymentDialog> {
  final _amountController = TextEditingController();
  String _selectedMethod = PaymentMethods.efectivoUsd;
  late double _remainingUSD;
  final List<Payment> _newPayments = [];

  @override
  void initState() {
    super.initState();
    _remainingUSD = widget.pending.deudaTotalUsd;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool _isBolivaresMethod(String method) {
    return [
      PaymentMethods.efectivoVes,
      PaymentMethods.pagoMovil,
      PaymentMethods.puntoDeVenta,
      PaymentMethods.transferencia,
    ].contains(method);
  }

  @override
  Widget build(BuildContext context) {
    final remainingVES = _remainingUSD * widget.rate;
    final isBolivares = _isBolivaresMethod(_selectedMethod);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Abonar Cuenta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
            child: Column(
              children: [
                const Text('Falta por Cobrar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('\\$${_remainingUSD > 0 ? _remainingUSD.toStringAsFixed(2) : "0.00"}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                if (_remainingUSD > 0)
                  Text('Bs. ${remainingVES.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_newPayments.isNotEmpty) ...[
            const Text('Abonos a procesar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._newPayments.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(PaymentMethods.label(p.method))),
                  Text('\\$${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _newPayments.remove(p);
                        _remainingUSD += p.amount;
                      });
                    },
                  ),
                ],
              ),
            )),
            const Divider(),
            const SizedBox(height: 8),
          ],
          
          if (_remainingUSD > 0.001) ...[ 
            DropdownButtonFormField<String>(
              value: _selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Método de Pago',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                DropdownMenuItem(value: PaymentMethods.efectivoUsd, child: Text(PaymentMethods.label(PaymentMethods.efectivoUsd))),
                DropdownMenuItem(value: PaymentMethods.pagoMovil, child: Text(PaymentMethods.label(PaymentMethods.pagoMovil))),
                DropdownMenuItem(value: PaymentMethods.efectivoVes, child: Text(PaymentMethods.label(PaymentMethods.efectivoVes))),
                DropdownMenuItem(value: PaymentMethods.puntoDeVenta, child: Text(PaymentMethods.label(PaymentMethods.puntoDeVenta))),
                DropdownMenuItem(value: PaymentMethods.transferencia, child: Text(PaymentMethods.label(PaymentMethods.transferencia))),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedMethod = val;
                    _amountController.clear();
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isBolivares ? 'Monto (Bs)' : 'Monto (\\$)',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _amountController.text.replaceAll(',', '.');
                    final input = double.tryParse(text) ?? 0;
                    if (input <= 0) {
                      CustomSnackBar.error(context, 'Monto inválido');
                      return;
                    }
                    
                    double inputUSD = isBolivares ? input / widget.rate : input;
                    
                    if (inputUSD > _remainingUSD && (inputUSD - _remainingUSD) < 0.02) {
                      inputUSD = _remainingUSD;
                    }

                    setState(() {
                      _newPayments.add(Payment(method: _selectedMethod, amount: inputUSD));
                      _remainingUSD -= inputUSD;
                      if (_remainingUSD < 0) _remainingUSD = 0;
                      _amountController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('AÑADIR'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _amountController.text = isBolivares ? remainingVES.toStringAsFixed(2) : _remainingUSD.toStringAsFixed(2);
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                child: Text('Abonar Total Restante (${isBolivares ? 'Bs' : '\\$'})'),
              ),
            ),
          ] else ...[
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Deuda cubierta', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _newPayments.isEmpty ? null : () => _confirmPayment(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: _remainingUSD <= 0.001 ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_remainingUSD <= 0.001 ? 'LIQUIDAR DEUDA' : 'CONFIRMAR ABONO PARCIAL', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _confirmPayment(BuildContext context, WidgetRef ref) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final basePayments = widget.pending.pagosPrevios.where((p) => p.method != PaymentMethods.pendiente).toList();
      List<Payment> finalPayments = [...basePayments, ..._newPayments];
      
      if (_remainingUSD > 0.001) {
        finalPayments.add(Payment(method: PaymentMethods.pendiente, amount: _remainingUSD));
      }
      
      await ref.read(pendingPaymentsProvider.notifier).updatePendingStatus(widget.pending.idVenta, finalPayments);
      
      if (context.mounted) {
        Navigator.pop(context); // close loading
        Navigator.pop(context); // close modal
        CustomSnackBar.success(context, _remainingUSD <= 0.001 ? 'Deuda liquidada con éxito.' : 'Abono procesado exitosamente.');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        CustomSnackBar.error(context, 'Error al procesar el abono: $e');
      }
    }
  }
}
"""
    content = content[:chip_idx] + dialog_impl

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)


import sys

file_path = "lib/features/sales/presentation/screens/pos_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_code = """  void _showAddPaymentDialog(BuildContext screenContext, WidgetRef ref) {
    showDialog(
      context: screenContext,
      barrierDismissible: false,
      builder: (dialogCtx) => const _MixedPaymentDialog(),
    ).then((confirmed) {
      if (confirmed == true) {
        _processCheckout(screenContext, ref);
      }
    });
  }

class _MixedPaymentDialog extends ConsumerStatefulWidget {
  const _MixedPaymentDialog({super.key});

  @override
  ConsumerState<_MixedPaymentDialog> createState() => _MixedPaymentDialogState();
}

class _MixedPaymentDialogState extends ConsumerState<_MixedPaymentDialog> {
  final _amountController = TextEditingController();
  String _selectedMethod = PaymentMethods.efectivoUsd;
  String? _debtorName;

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
    final payments = ref.watch(paymentsProvider);
    final totalUSD = ref.read(cartProvider.notifier).totalCartUSD;
    final totalPaidUSD = ref.watch(paymentsProvider.notifier).totalPaid;
    final remainingUSD = totalUSD - totalPaidUSD;

    final exchangeRate = ref.read(exchangeRateProvider).value?.rate ?? 36.0;
    final remainingVES = remainingUSD * exchangeRate;

    final isBolivares = _isBolivaresMethod(_selectedMethod);

    return AlertDialog(
      title: const Text('Pagos Mixtos / Múltiples', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal.withOpacity(0.3))),
                child: Column(
                  children: [
                    const Text('Falta por Pagar', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('\\$${remainingUSD > 0 ? remainingUSD.toStringAsFixed(2) : "0.00"}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                    if (remainingUSD > 0)
                      Text('Bs. ${remainingVES.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (payments.isNotEmpty) ...[
                const Text('Pagos Registrados:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                ...payments.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(PaymentMethods.label(p.method), style: const TextStyle(fontSize: 14))),
                      Text('\\$${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ref.read(paymentsProvider.notifier).removePayment(p),
                      ),
                    ],
                  ),
                )),
                const Divider(),
                const SizedBox(height: 8),
              ],
              
              if (remainingUSD > 0.001) ...[ 
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
                    DropdownMenuItem(value: PaymentMethods.pendiente, child: Text(PaymentMethods.label(PaymentMethods.pendiente))),
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
                if (_selectedMethod == PaymentMethods.pendiente) ...[
                  TextField(
                    onChanged: (v) => _debtorName = v,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Deudor / Cliente',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                        if (_selectedMethod == PaymentMethods.pendiente && (_debtorName == null || _debtorName!.trim().isEmpty)) {
                          CustomSnackBar.warning(context, 'Ingresa el nombre del deudor');
                          return;
                        }
                        
                        final text = _amountController.text.replaceAll(',', '.');
                        final input = double.tryParse(text) ?? 0;
                        if (input <= 0) {
                          CustomSnackBar.error(context, 'Ingresa un monto válido');
                          return;
                        }
                        
                        double inputUSD = isBolivares ? input / exchangeRate : input;
                        
                        if (inputUSD > remainingUSD && (inputUSD - remainingUSD) < 0.02) {
                          inputUSD = remainingUSD;
                        }

                        if (_selectedMethod == PaymentMethods.pendiente) {
                           ref.read(debtorNameProvider.notifier).state = _debtorName!;
                        }

                        ref.read(paymentsProvider.notifier).addPayment(Payment(method: _selectedMethod, amount: inputUSD));
                        _amountController.clear();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                      child: const Text('AÑADIR'),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _amountController.text = isBolivares ? remainingVES.toStringAsFixed(2) : remainingUSD.toStringAsFixed(2);
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    child: Text('Sugerir restante (${isBolivares ? 'Bs' : '\\$'})'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Pago completo', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cerrar / Editar luego', style: TextStyle(color: Colors.grey)),
        ),
        if (remainingUSD <= 0.001)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Confirmar Venta'),
          ),
      ],
    );
  }
}
\n"""

lines = lines[:711] + [new_code] + lines[898:]
with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(lines)

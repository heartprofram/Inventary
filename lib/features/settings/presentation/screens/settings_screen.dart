import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchangeRateState = ref.watch(exchangeRateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tasa de Cambio (VES/USD)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            exchangeRateState.when(
              data: (rate) {
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tasa Actual:', style: TextStyle(fontSize: 18)),
                            Text('Bs. ${rate.rate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Última actualización: ${rate.lastUpdated.toString().substring(0, 16)}', style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                ref.read(exchangeRateProvider.notifier).fetchBcvRate();
                              },
                              icon: const Icon(Icons.sync),
                              label: const Text('Tasa Automática (BCV)'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                _showManualRateDialog(context, ref, rate.rate);
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Tasa Manual'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Error: $err', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(exchangeRateProvider.notifier).fetchBcvRate(),
                        child: const Text('Reintentar'),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualRateDialog(BuildContext context, WidgetRef ref, double currentRate) {
    final controller = TextEditingController(text: currentRate.toString());
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ingresar Tasa Manual'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: const InputDecoration(
              labelText: 'Tasa (VES)',
              prefixText: 'Bs. ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final newRate = double.tryParse(controller.text);
                if (newRate != null && newRate > 0) {
                  ref.read(exchangeRateProvider.notifier).setManualRate(newRate);
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

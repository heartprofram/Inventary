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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SECCIÓN: TASA DE CAMBIO BCV
              _buildSectionHeader('TASA DE CAMBIO BCV'),
              const SizedBox(height: 12),
              exchangeRateState.when(
                data: (rate) {
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tasa Actual:', style: TextStyle(fontSize: 18)),
                              Text('Bs. ${rate.rate.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Última actualización: ${rate.lastUpdated.toString().substring(0, 16)}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12.0,
                            runSpacing: 12.0,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(exchangeRateProvider.notifier).fetchBcvRate();
                                },
                                icon: const Icon(Icons.sync),
                                label: const Text('Actualizar del BCV'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade50,
                                  foregroundColor: Colors.teal,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _showManualRateDialog(context, ref, rate.rate);
                                },
                                icon: const Icon(Icons.edit_note),
                                label: const Text('Ajuste Manual'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                )),
                error: (err, stack) => Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 12),
                        Text('Error al cargar tasa: $err', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
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
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade700,
          letterSpacing: 1.2,
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
          title: const Text('Establecer Tasa Manual'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: const InputDecoration(
              labelText: 'Nueva Tasa (VES)',
              prefixText: 'Bs. ',
              border: OutlineInputBorder(),
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar Tasa'),
            ),
          ],
        );
      },
    );
  }
}

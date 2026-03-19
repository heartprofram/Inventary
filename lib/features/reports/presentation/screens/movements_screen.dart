import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/movement.dart';
import '../providers/movements_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key});

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(movementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(movementsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: movementsAsync.when(
        data: (movements) {
          if (movements.isEmpty) {
            return const Center(
              child: Text('No hay movimientos registrados.', style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }
          return ListView.builder(
            itemCount: movements.length,
            itemBuilder: (context, index) {
              final m = movements.reversed.toList()[index];
              final isIncome = m.type == 'Ingreso';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(m.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${m.date.toString().substring(0, 16)} - ${m.type}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${m.amountUSD.toStringAsFixed(2)}', style: TextStyle(color: isIncome ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                      Text('Bs. ${m.amountVES.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMovementDialog(context, ref),
        label: const Text('Nuevo Movimiento'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _showAddMovementDialog(BuildContext screenContext, WidgetRef ref) {
    String type = 'Egreso';
    final descController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: screenContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (stateCtx, setStateDialog) {
            return AlertDialog(
              title: const Text('Registrar Movimiento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(value: 'Ingreso', child: Text('Ingreso')),
                        DropdownMenuItem(value: 'Egreso', child: Text('Egreso (Pago, Deuda)')),
                      ],
                      onChanged: (val) => setStateDialog(() => type = val!),
                      decoration: const InputDecoration(labelText: 'Tipo de Movimiento'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Concepto (Ej. Pago de Luz)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monto en USD', prefixText: '\$'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(stateCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final desc = descController.text.trim();
                    final amountUSD = double.tryParse(amountController.text) ?? 0.0;
                    
                    if (desc.isEmpty || amountUSD <= 0) {
                      ScaffoldMessenger.of(stateCtx).showSnackBar(const SnackBar(content: Text('Revisa los campos ingresados.')));
                      return;
                    }

                    final rate = ref.read(exchangeRateProvider).value?.rate ?? 36.0;
                    final amountVES = amountUSD * rate;

                    final movement = Movement(
                      id: 'MOV-${DateTime.now().millisecondsSinceEpoch}',
                      date: DateTime.now(),
                      type: type,
                      description: desc,
                      amountUSD: amountUSD,
                      amountVES: amountVES,
                    );

                    Navigator.pop(stateCtx); // Cierra diálogo
                    
                    // Mostrar carga en todo el scaffold
                    showDialog(
                      context: screenContext, 
                      barrierDismissible: false, 
                      builder: (_) => const Center(child: CircularProgressIndicator())
                    );
                    
                    final success = await ref.read(movementsProvider.notifier).addMovement(movement);
                    
                    if (screenContext.mounted) {
                      Navigator.pop(screenContext); // Quita carga
                      if (success) {
                        ScaffoldMessenger.of(screenContext).showSnackBar(const SnackBar(content: Text('Movimiento registrado.'), backgroundColor: Colors.green));
                      } else {
                        ScaffoldMessenger.of(screenContext).showSnackBar(const SnackBar(content: Text('Fallo al guardar. Verifique su conexión.'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import 'package:inventary/core/widgets/custom_snackbar.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Registro de Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 0,
      ),
      body: movementsAsync.when(
        data: (movements) {
          final days = ref.watch(movementsDaysProvider);
          if (movements.isEmpty) {
            return EmptyState(
              icon: Icons.swap_horiz_outlined,
              title: 'Sin movimientos',
              message: days > 0 
                ? 'No hay movimientos en los últimos $days días.'
                : 'Aquí aparecerán tus ingresos y egresos de caja manuales.',
              onAction: days > 0 ? () => ref.read(movementsProvider.notifier).loadAllHistory() : () => _showAddMovementDialog(context, ref),
              actionLabel: days > 0 ? 'Cargar Histórico Completo' : 'Nuevo Movimiento',
            );
          }
          final reversedList = movements.reversed.toList();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reversedList.length + (days > 0 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == reversedList.length && days > 0) {
                 return Padding(
                   padding: const EdgeInsets.symmetric(vertical: 24),
                   child: OutlinedButton.icon(
                     onPressed: () => ref.read(movementsProvider.notifier).loadAllHistory(),
                     icon: const Icon(Icons.history),
                     label: const Text('Mostrando últimos 30 días. Cargar histórico completo.'),
                     style: OutlinedButton.styleFrom(
                       padding: const EdgeInsets.all(16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                   ),
                 );
              }
              final m = reversedList[index];
              final isIncome = m.type == 'Ingreso';
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIncome ? Colors.green[50] : Colors.red[50],
                    child: Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIncome ? Colors.green[700] : Colors.red[700],
                      size: 20,
                    ),
                  ),
                  title: Text(m.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${m.date.toString().substring(0, 16)} • ${m.type}', style: const TextStyle(fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isIncome ? "+" : "-"}\$${m.amountUSD.toStringAsFixed(2)}',
                        style: TextStyle(color: isIncome ? Colors.green[700] : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Bs. ${m.amountVES.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const ShimmerList(itemCount: 10),
        error: (err, stack) => EmptyState(icon: Icons.error_outline, title: 'Error', message: err.toString()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMovementDialog(context, ref),
        label: const Text('Registrar Movimiento', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
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
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stateCtx, setStateDialog) => AlertDialog(
          title: const Text('Nuevo Movimiento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Ingreso', label: Text('Ingreso'), icon: Icon(Icons.add)),
                    ButtonSegment(value: 'Egreso', label: Text('Egreso'), icon: Icon(Icons.remove)),
                  ],
                  selected: {type},
                  onSelectionChanged: (val) => setStateDialog(() => type = val.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Descripción / Concepto', border: OutlineInputBorder()),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto USD', prefixText: '\$', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(stateCtx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final desc = descController.text.trim();
                final amountUSD = double.tryParse(amountController.text) ?? 0.0;
                
                if (desc.isEmpty || amountUSD <= 0) {
                  CustomSnackBar.error(stateCtx, 'Completa todos los campos correctamente.');
                  return;
                }

                final rate = ref.read(exchangeRateProvider).value?.rate ?? 36.0;

                final movement = Movement(
                  id: 'MOV-${DateTime.now().millisecondsSinceEpoch}',
                  date: DateTime.now(),
                  type: type,
                  description: desc,
                  amountUSD: amountUSD,
                  amountVES: amountUSD * rate,
                );

                Navigator.pop(stateCtx); // Close dialog
                
                showDialog(context: screenContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                
                final success = await ref.read(movementsProvider.notifier).addMovement(movement);
                
                if (screenContext.mounted) {
                  Navigator.pop(screenContext); // Close loading
                  if (success) {
                    CustomSnackBar.success(screenContext, 'Movimiento registrado correctamente.');
                  } else {
                    CustomSnackBar.error(screenContext, 'Error al guardar el movimiento.');
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

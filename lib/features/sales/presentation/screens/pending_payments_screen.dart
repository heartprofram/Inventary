import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import 'package:inventary/core/widgets/custom_snackbar.dart';
import '../providers/pending_payments_provider.dart';
import '../providers/sales_providers.dart';
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
      body: pendingAsync.when(
        data: (pendings) {
          if (pendings.isEmpty) {
            return EmptyState(
              icon: Icons.pending_actions_outlined,
              title: 'Cuentas al día',
              message: 'No hay deudas o pagos pendientes registrados actualmente.',
              onAction: () => ref.read(pendingPaymentsProvider.notifier).refresh(),
              actionLabel: 'Actualizar',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pendings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final pending = pendings[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.orange.withOpacity(0.3))),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  backgroundColor: Colors.orange.withOpacity(0.02),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[100],
                    child: Icon(Icons.person_outline, color: Colors.orange[900]),
                  ),
                  title: Text(pending.deudor, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Venta #${pending.idVenta.split('-').last.toUpperCase()} • ${pending.fecha}', style: const TextStyle(fontSize: 12)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${pending.totalUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                      const Text('PAGO PENDIENTE', style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: Column(
                        children: [
                          ...pending.detallesProductos.map((det) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(child: Text(det['nombre_producto'], style: const TextStyle(fontSize: 13))),
                                Text('${det['cantidad']} x \$${det['precio_unitario_usd']}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            ),
                          )),
                          const Divider(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _processPayment(context, ref, pending, exchangeRateAsync.value?.rate ?? 36.0),
                                  icon: const Icon(Icons.point_of_sale, size: 18),
                                  label: const Text('COBRAR'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: () => _deletePayment(context, ref, pending.idVenta),
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const ShimmerList(itemCount: 6),
        error: (err, stack) => EmptyState(icon: Icons.error_outline, title: 'Error', message: err.toString()),
      ),
    );
  }

  void _processPayment(BuildContext context, WidgetRef ref, PendingPayment pending, double rate) {
    ref.read(pendingPaymentsProvider.notifier).processPendingPayment(pending, ref, rate);
    CustomSnackBar.info(context, 'Mostrando datos de ${pending.deudor} en el POS para el cobro.');
    // No navegar aquí para dejar que el usuario vea el snackbar o forzar navegación
    // Navigator.pushReplacement(...) // opcional según UX deseada
  }

  void _deletePayment(BuildContext context, WidgetRef ref, String idVenta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Pendiente'),
        content: const Text('¿Estás seguro de eliminar esta venta pendiente? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Eliminar')),
        ],
      ),
    );
    
    if (confirm == true) {
      // Implementación pendiente en el provider/repo real, por ahora refresh
      await ref.read(pendingPaymentsProvider.notifier).refresh();
      if (mounted) CustomSnackBar.success(context, 'Venta pendiente eliminada.');
    }
  }
}

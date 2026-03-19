import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pending_payments_provider.dart';
import '../providers/sales_providers.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import 'pos_screen.dart';

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
      appBar: AppBar(
        title: const Text('Cuentas por Cobrar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(pendingPaymentsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: pendingAsync.when(
        data: (pendings) {
          if (pendings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay pagos pendientes', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendings.length,
            itemBuilder: (context, index) {
              final pending = pendings[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(pending.deudor, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${pending.idVenta}'),
                      Text('Fecha: ${pending.fecha}'),
                      Text('\$${pending.totalUsd.toStringAsFixed(2)} USD'),
                      Text('${pending.detallesProductos.length} productos'),
                    ],
                  ),
                  children: [
                    // Detalles productos
                    ...pending.detallesProductos.map((det) => ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: Text(det['nombre_producto']),
                      subtitle: Text('${det['cantidad']} x \$${det['precio_unitario_usd']} = \$${det['subtotal_usd']}'),
                    )),
                    // Acciones
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              onPressed: () => _processPayment(context, ref, pending, exchangeRateAsync.value?.rate ?? 36.0),
                              icon: const Icon(Icons.point_of_sale, color: Colors.white),
                              label: const Text('Procesar Pago', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              onPressed: () => _editPayment(context, pending),
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => _deletePayment(context, ref, pending.idVenta),
                              icon: const Icon(Icons.delete),
                              label: const Text('Eliminar'),
                            ),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $err'),
              ElevatedButton(
                onPressed: () => ref.read(pendingPaymentsProvider.notifier).refresh(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processPayment(BuildContext context, WidgetRef ref, PendingPayment pending, double rate) {
    ref.read(pendingPaymentsProvider.notifier).processPendingPayment(pending, ref, rate);
    
    // Navegar a POS con datos precargados (o mostrar modal POS-like)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Datos de ${pending.deudor} cargados en POS. Completa el pago.')),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PosScreen()),
    );
  }

  void _editPayment(BuildContext context, PendingPayment pending) {
    // TODO: Implementar edición (navegar a edit_sale_screen con datos)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Editar ${pending.deudor} (Próximamente)')),
    );
  }

  void _deletePayment(BuildContext context, WidgetRef ref, String idVenta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar venta pendiente? Se revertirá stock.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              // TODO: Implementar delete endpoint/backend si necesario
              // Por ahora solo refresh
              await ref.read(pendingPaymentsProvider.notifier).refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Eliminado (simulado)')),
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventary/core/widgets/shimmer_loading.dart';
import 'package:inventary/core/widgets/empty_state.dart';
import '../providers/reports_provider.dart';
import 'movements_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(reportsProvider);

    return Scaffold(
      body: reportsState.when(
        data: (metrics) {
          if (metrics.sales.isEmpty) {
            return EmptyState(
              icon: Icons.analytics_outlined,
              title: 'Sin ventas hoy',
              message: 'Aún no se han registrado transacciones en el sistema hoy.',
              onAction: () => ref.read(reportsProvider.notifier).refresh(),
              actionLabel: 'Actualizar',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Resumen del Día', 'Métricas clave de hoy'),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 600;
                    return isWide 
                        ? Row(
                            children: [
                              Expanded(child: _MetricCard(title: 'Facturas', value: metrics.sales.length.toString(), icon: Icons.receipt_long, color: Colors.blue)),
                              const SizedBox(width: 16),
                              Expanded(child: _MetricCard(title: 'Total USD', value: '\$${metrics.totalUSD.toStringAsFixed(2)}', icon: Icons.attach_money, color: Colors.green)),
                            ],
                          )
                        : Column(
                            children: [
                              _MetricCard(title: 'Facturas Emitidas', value: metrics.sales.length.toString(), icon: Icons.receipt_long, color: Colors.blue),
                              const SizedBox(height: 16),
                              _MetricCard(title: 'Ingresos Totales (USD)', value: '\$${metrics.totalUSD.toStringAsFixed(2)}', icon: Icons.attach_money, color: Colors.green),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 16),
                _MetricCard(
                  title: 'Ingresos Equivalentes (VES)',
                  value: 'Bs. ${metrics.totalVES.toStringAsFixed(2)}',
                  icon: Icons.currency_exchange,
                  color: Colors.orange,
                ),
                const SizedBox(height: 32),
                _buildSectionHeader('Desglose de Pagos', 'Por método seleccionado'),
                const SizedBox(height: 16),
                ...metrics.paymentsUSD.entries.map((entry) {
                  final vesVal = metrics.paymentsVES[entry.key] ?? 0.0;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.teal, foregroundColor: Colors.white, child: Icon(Icons.payment, size: 20)),
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Equivalente Bs. ${vesVal.toStringAsFixed(2)}'),
                      trailing: Text('\$${entry.value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                    ),
                  );
                }),
                const SizedBox(height: 40),
                if (metrics.isClosed) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green[200]!)),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 48),
                        SizedBox(height: 12),
                        Text('Caja Cerrada', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                        Text('El Reporte Z ha sido generado y sincronizado.', textAlign: TextAlign.center, style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: () => _confirmCloseRegister(context, ref),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('REALIZAR CIERRE DE CAJA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                   onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MovementsScreen())),
                   icon: const Icon(Icons.history),
                   label: const Text('VER REGISTRO DE MOVIMIENTOS'),
                   style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          );
        },
        loading: () => const ShimmerList(itemCount: 5),
        error: (err, stack) => EmptyState(icon: Icons.error_outline, title: 'Error', message: err.toString()),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  void _confirmCloseRegister(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cierre de Caja'),
        content: const Text('¿Estás seguro de cerrar la caja? Se generará el Reporte Z PDF y se reiniciarán las métricas diarias.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(reportsProvider.notifier).generateAndCloseRegister();
            },
            child: const Text('Confirmar Cierre'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reports_provider.dart';
import 'movements_screen.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsState = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre de Caja y Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(reportsProvider.notifier).refresh();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: reportsState.when(
        data: (metrics) {
          if (metrics.sales.isEmpty) {
            return const Center(
              child: Text(
                'No hay ventas registradas el día de hoy.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Resumen Diario (Reporte Z)',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _MetricCard(
                  title: 'Facturas Emitidas',
                  value: metrics.sales.length.toString(),
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _MetricCard(
                  title: 'Ingresos Totales (USD)',
                  value: '\$${metrics.totalUSD.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _MetricCard(
                  title: 'Ingresos Equivalentes (VES)',
                  value: 'Bs. ${metrics.totalVES.toStringAsFixed(2)}',
                  icon: Icons.money,
                  color: Colors.orange,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.blueGrey,
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MovementsScreen()));
                  },
                  icon: const Icon(Icons.list_alt, color: Colors.white),
                  label: const Text('VER MOVIMIENTOS', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                if (metrics.isClosed) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const Text('Caja Cerrada Exitosamente. PDF Generado guardado en dispositivo.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 24),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.teal,
                    ),
                    onPressed: () => _confirmCloseRegister(context, ref),
                    icon: const Icon(Icons.point_of_sale, color: Colors.white),
                    label: const Text('CERRAR CAJA', style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ]
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error al cargar ventas: $err')),
      ),
    );
  }

  void _confirmCloseRegister(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Cerrar Caja?'),
          content: const Text('Al cerrar la caja se generará y subirá el Reporte Z a Google Drive. Esta acción consolida las ventas del día.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(reportsProvider.notifier).generateAndCloseRegister();
              },
              child: const Text('Sí, Cerrar Caja'),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 30,
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

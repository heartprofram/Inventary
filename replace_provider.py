import sys

file_path = "lib/features/sales/presentation/providers/pending_payments_provider.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_class = """class PendingPayment {
  final String idVenta;
  final String fecha;
  final double totalUsd;
  final double deudaTotalUsd;
  final List<Payment> pagosPrevios;
  final String deudor;
  final List<Map<String, dynamic>> detallesProductos;

  PendingPayment({
    required this.idVenta,
    required this.fecha,
    required this.totalUsd,
    required this.deudaTotalUsd,
    required this.pagosPrevios,
    required this.deudor,
    required this.detallesProductos,
  });

  Sale toSale(double currentRate) {
    final details = detallesProductos.map((d) => SaleDetail(
      productId: d['id_producto'],
      productName: d['nombre_producto'],
      quantity: (d['cantidad'] as num).toInt(),
      unitPriceUSD: (d['precio_unitario_usd'] as num).toDouble(),
    )).toList();

    return Sale(
      id: idVenta,
      date: DateTime.parse(fecha),
      exchangeRate: currentRate,
      details: details,
      payments: pagosPrevios,
      debtorName: deudor,
    );
  }
}
"""

new_fetch = """  Future<List<PendingPayment>> _fetchPending() async {
    final salesRepo = ref.read(salesRepositoryProvider);
    final allSales = await salesRepo.getSalesHistory();
    
    final pendingSales = allSales.where((sale) {
      return sale.payments.any((p) => p.method == PaymentMethods.pendiente);
    }).toList();

    return pendingSales.map((sale) {
      final overridePendings = sale.payments.where((p) => p.method == PaymentMethods.pendiente);
      final deuda = overridePendings.isNotEmpty ? overridePendings.fold(0.0, (sum, p) => sum + p.amount) : sale.totalUSD;
      
      return PendingPayment(
        idVenta: sale.id,
        fecha: sale.date.toIso8601String(),
        totalUsd: sale.totalUSD,
        deudaTotalUsd: deuda,
        pagosPrevios: sale.payments,
        deudor: sale.debtorName ?? '',
        detallesProductos: sale.details.map((d) => {
          'id_producto': d.productId,
          'nombre_producto': d.productName,
          'cantidad': d.quantity,
          'precio_unitario_usd': d.unitPriceUSD,
        }).toList(),
      );
    }).toList();
  }
"""

# Replace PendingPayment class
# Find class start and end
class_start = -1
class_end = -1
for i, line in enumerate(lines):
    if line.startswith("class PendingPayment {"):
        class_start = i
    if line.startswith("}") and class_start != -1 and class_end == -1:
        if i > class_start + 10:
            class_end = i
            break

lines1 = lines[:class_start] + [new_class] + lines[class_end+1:]

fetch_start = -1
fetch_end = -1
for i, line in enumerate(lines1):
    if line.startswith("  Future<List<PendingPayment>> _fetchPending() async {"):
        fetch_start = i
    if line.startswith("  Future<void> processPendingPayment") and fetch_start != -1:
        fetch_end = i
        break

lines2 = lines1[:fetch_start] + [new_fetch, "\n"] + lines1[fetch_end:]

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(lines2)

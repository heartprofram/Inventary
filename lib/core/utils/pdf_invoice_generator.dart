import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../features/sales/domain/sale.dart';

class PdfInvoiceGenerator {
  static Future<Uint8List> generateSalesReport(List<Sale> sales, String periodName) async {
    final pdf = pw.Document();
    final totalUSD = sales.fold(0.0, (sum, sale) => sum + sale.totalUSD);
    final totalVES = sales.fold(0.0, (sum, sale) => sum + sale.totalVES);
    final now = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                children: [
                  pw.Center(child: pw.Text('REPORTE DE VENTAS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 4),
                  pw.Center(child: pw.Text('Período: $periodName', style: const pw.TextStyle(fontSize: 14))),
                  pw.SizedBox(height: 2),
                  pw.Center(child: pw.Text('Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))),
                  pw.SizedBox(height: 16),
                ],
              ),
            ),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              headers: ['Fecha', 'Cliente', 'Tasa (VES)', 'Total USD', 'Total VES'],
              data: sales.map((sale) => [
                DateFormat('dd/MM/yyyy HH:mm').format(sale.date),
                sale.debtorName ?? 'Contado',
                sale.exchangeRate.toStringAsFixed(2),
                '\$${sale.totalUSD.toStringAsFixed(2)}',
                'Bs. ${sale.totalVES.toStringAsFixed(2)}',
              ]).toList(),
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('VENTAS TOTALES USD:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      pw.Text('\$${totalUSD.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.green)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('VENTAS TOTALES VES:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('Bs. ${totalVES.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateInvoice(Sale sale) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('TIENDA POS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Text('Factura Nro: ${sale.id}'),
              pw.Text('Fecha: ${sale.date.toString().substring(0, 16)}'),
              pw.Text('Tasa de Cambio: ${sale.exchangeRate} VES/USD'),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Cant.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ]
              ),
              pw.Divider(),
              ...sale.details.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text(item.productName, maxLines: 1)),
                    pw.Expanded(flex: 1, child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 1, child: pw.Text('\$${item.subtotalUSD.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                  ]
                ),
              )).toList(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL USD:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text('\$${sale.totalUSD.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL VES:'),
                  pw.Text('Bs. ${sale.totalVES.toStringAsFixed(2)}'),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Metodo de Pago:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(sale.paymentMethodLabel),
                ]
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Gracias por su compra!', style: const pw.TextStyle(fontSize: 12))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateSimpleInvoice(Sale sale) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('CUENTA POR COBRAR', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Text('Nro: ${sale.id}'),
              pw.Text('Deudor: ${sale.debtorName ?? 'N/A'}'),
              pw.Text('Fecha: ${sale.date.toString().substring(0, 16)}'),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Producto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Cant.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                ]
              ),
              pw.Divider(),
              ...sale.details.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text(item.productName, maxLines: 1)),
                    pw.Expanded(flex: 1, child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 1, child: pw.Text('\$${item.subtotalUSD.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                  ]
                ),
              )).toList(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL USD:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text('\$${sale.totalUSD.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ]
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('PAGO PENDIENTE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateZReport(List<Sale> sales, double totalUSD, double totalVES) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('REPORTE Z', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 10),
              pw.Text('Fecha: ${now.toString().substring(0, 16)}'),
              pw.Text('Total de Ventas Realizadas: ${sales.length}'),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ID Venta', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Hora', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('USD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ]
              ),
              pw.Divider(),
              ...sales.map((sale) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(sale.id, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(sale.date.toString().substring(11, 16), style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('\$${sale.totalUSD.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                ]
              )).toList(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL INGRESOS USD:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('\$${totalUSD.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL INGRESOS VES:'),
                  pw.Text('Bs. ${totalVES.toStringAsFixed(2)}'),
                ]
              ),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('CIERRE DE CAJA DIARIO', style: const pw.TextStyle(fontSize: 12))),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
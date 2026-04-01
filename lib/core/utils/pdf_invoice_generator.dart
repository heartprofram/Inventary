import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:inventary/features/sales/domain/sale.dart';

// ─── PALETA DE COLORES UNIFICADA ───
const _kDarkGreen = PdfColor.fromInt(0xFF004D40);
const _kLightGrey = PdfColor.fromInt(0xFFF5F5F5);
const _kOrange = PdfColor.fromInt(0xFFE65100);
const _kLightOrange = PdfColor.fromInt(0xFFFFF3E0);
const _kTextDark = PdfColor.fromInt(0xFF212121);
const _kTextGrey = PdfColor.fromInt(0xFF757575);
const _kDivider = PdfColor.fromInt(0xFFE0E0E0);
const _kWhite = PdfColors.white;

class PdfInvoiceGenerator {
  static pw.Widget _divider() =>
      pw.Divider(height: 1, thickness: 1, color: _kDivider);

  static pw.Widget _buildHeader(
    String documentType, {
    String? subtitle,
    PdfColor color = _kDarkGreen,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'INVENTORY',
            style: pw.TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          color: color,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Center(
            child: pw.Text(
              documentType.toUpperCase(),
              style: pw.TextStyle(
                color: _kWhite,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              subtitle,
              style: pw.TextStyle(color: _kTextGrey, fontSize: 8),
            ),
          ),
        ],
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(
    String title, {
    PdfColor color = _kDarkGreen,
    PdfColor bg = _kLightGrey,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          color: bg,
          padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: pw.Text(
            '> $title',
            style: pw.TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(color: _kTextGrey, fontSize: 9)),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _kTextDark,
              fontSize: 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalsBox(
    double totalUSD,
    double totalVES, {
    PdfColor color = _kDarkGreen,
    String title = 'TOTALES',
    String labelUSD = 'TOTAL USD:',
    String labelVES = 'TOTAL VES:',
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: _kWhite,
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        children: [
          pw.Center(
            child: pw.Text(
              title,
              style: pw.TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: _kDivider, thickness: 1),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                labelUSD,
                style: pw.TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '\$${totalUSD.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                labelVES,
                style: pw.TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Bs. ${totalVES.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(String message) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 16),
        _divider(),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            message,
            style: pw.TextStyle(color: _kTextGrey, fontSize: 8),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Inventory & POS v1.9.3',
            style: pw.TextStyle(color: _kTextGrey, fontSize: 7),
          ),
        ),
      ],
    );
  }

  static Future<Uint8List> generateZReport(
    List<Sale> sales,
    double totalUSD,
    double totalVES,
  ) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    double efectivoBs_usd = 0.0, efectivoBs_ves = 0.0, efectivoUsd_usd = 0.0;
    double pagoMovil_usd = 0.0,
        pagoMovil_ves = 0.0,
        puntoVenta_usd = 0.0,
        puntoVenta_ves = 0.0;
    final Map<String, Map<String, dynamic>> aggregatedItems = {};

    for (var sale in sales) {
      for (var payment in sale.payments) {
        final method = payment.method.toLowerCase();
        final amountUSD = payment.amount;
        final amountVES = amountUSD * sale.exchangeRate;

        if (method.contains('usd') || method.contains('\$')) {
          efectivoUsd_usd += amountUSD;
        } else if (method.contains('móvil') || method.contains('movil')) {
          pagoMovil_usd += amountUSD;
          pagoMovil_ves += amountVES;
        } else if (method.contains('punto') || method.contains('tarjeta')) {
          puntoVenta_usd += amountUSD;
          puntoVenta_ves += amountVES;
        } else if (!method.contains('transferencia') &&
            !method.contains('pendiente')) {
          efectivoBs_usd += amountUSD;
          efectivoBs_ves += amountVES;
        }
      }

      for (var detail in sale.details) {
        if (aggregatedItems.containsKey(detail.productId)) {
          aggregatedItems[detail.productId]!['qty'] += detail.quantity;
          aggregatedItems[detail.productId]!['total'] += detail.subtotalUSD;
        } else {
          aggregatedItems[detail.productId] = {
            'name': detail.productName,
            'qty': detail.quantity,
            'total': detail.subtotalUSD,
          };
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                'Cierre de Caja',
                subtitle: 'Reporte Z de Operaciones',
              ),
              _buildInfoRow(
                'Fecha y Hora:',
                DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                isBold: true,
              ),
              _buildInfoRow('Transacciones:', '${sales.length}', isBold: true),
              pw.SizedBox(height: 8),

              _buildSectionTitle('RESUMEN DE INGRESOS'),
              if (efectivoBs_usd > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '• Efectivo (Bs):',
                        style: pw.TextStyle(color: _kTextGrey, fontSize: 9),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            '\$${efectivoBs_usd.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              color: _kDarkGreen,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Bs. ${efectivoBs_ves.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              color: _kDarkGreen,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (efectivoUsd_usd > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '• Efectivo (\$):',
                        style: pw.TextStyle(color: _kTextGrey, fontSize: 9),
                      ),
                      pw.Text(
                        '\$${efectivoUsd_usd.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          color: _kDarkGreen,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              if (pagoMovil_usd > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '• Pago Movil:',
                        style: pw.TextStyle(color: _kTextGrey, fontSize: 9),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            '\$${pagoMovil_usd.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              color: _kDarkGreen,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Bs. ${pagoMovil_ves.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              color: _kDarkGreen,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (puntoVenta_usd > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '• Tarjeta (Punto):',
                        style: pw.TextStyle(color: _kTextGrey, fontSize: 9),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            '\$${puntoVenta_usd.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              color: _kDarkGreen,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Bs. ${puntoVenta_ves.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              color: _kDarkGreen,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              pw.SizedBox(height: 8),

              _buildSectionTitle('INVENTARIO MOVILIZADO'),
              if (aggregatedItems.isEmpty)
                pw.Text(
                  'No hay artículos registrados.',
                  style: pw.TextStyle(fontSize: 8, color: _kTextGrey),
                )
              else
                ...aggregatedItems.values.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 20,
                          child: pw.Text(
                            '${item['qty']}x',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _kDarkGreen,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            item['name'],
                            style: pw.TextStyle(fontSize: 8, color: _kTextDark),
                          ),
                        ),
                        pw.Text(
                          '\$${(item['total'] as double).toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: _kTextDark,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(), // <-- CLAVE: .toList() AGREGADO

              pw.SizedBox(height: 12),
              _buildTotalsBox(totalUSD, totalVES),
              _buildFooter('Cierre de caja completado exitosamente.'),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateInvoice(Sale sale) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader('Recibo de Venta'),
              _buildInfoRow(
                'Nro Ticket:',
                sale.id.length > 8
                    ? sale.id.substring(0, 8).toUpperCase()
                    : sale.id,
                isBold: true,
              ),
              _buildInfoRow(
                'Fecha:',
                DateFormat('dd/MM/yyyy HH:mm').format(sale.date),
              ),
              _buildInfoRow(
                'Tasa BCV:',
                '${sale.exchangeRate.toStringAsFixed(2)} VES/USD',
              ),
              if ((sale.debtorName ?? '').isNotEmpty)
                _buildInfoRow('Cliente:', sale.debtorName!, isBold: true),
              pw.SizedBox(height: 8),

              _buildSectionTitle('ARTÍCULOS'),
              ...sale.details
                  .map(
                    (item) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 20,
                            child: pw.Text(
                              '${item.quantity}x',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: _kDarkGreen,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              item.productName,
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: _kTextDark,
                              ),
                            ),
                          ),
                          pw.Text(
                            '\$${item.subtotalUSD.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _kTextDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(), // <-- CLAVE: .toList() AGREGADO
              pw.SizedBox(height: 8),

              _buildSectionTitle('MÉTODO DE PAGO'),
              ...sale.payments
                  .map(
                    (p) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '• ${p.method}',
                            style: pw.TextStyle(fontSize: 9, color: _kTextGrey),
                          ),
                          pw.Text(
                            '\$${p.amount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: _kDarkGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(), // <-- CLAVE: .toList() AGREGADO
              pw.SizedBox(height: 12),

              _buildTotalsBox(sale.totalUSD, sale.totalVES),
              _buildFooter('¡Gracias por su compra! Vuelva pronto.'),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateSimpleInvoice(Sale sale) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    double pendienteUSD = 0.0;
    for (var p in sale.payments) {
      if (p.method.toLowerCase().contains('pendiente')) {
        pendienteUSD += p.amount;
      }
    }
    if (pendienteUSD == 0.0) pendienteUSD = sale.totalUSD;
    final pendienteVES = pendienteUSD * sale.exchangeRate;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildHeader(
                'Cuenta por Cobrar',
                subtitle: 'DOCUMENTO DE DEUDA PENDIENTE',
                color: _kOrange,
              ),
              _buildInfoRow(
                'Nro Ticket:',
                sale.id.length > 8
                    ? sale.id.substring(0, 8).toUpperCase()
                    : sale.id,
                isBold: true,
              ),
              _buildInfoRow(
                'Fecha:',
                DateFormat('dd/MM/yyyy HH:mm').format(sale.date),
              ),
              _buildInfoRow(
                'Tasa BCV:',
                '${sale.exchangeRate.toStringAsFixed(2)} VES/USD',
              ),
              _buildInfoRow(
                'Deudor:',
                sale.debtorName ?? 'Cliente No Registrado',
                isBold: true,
              ),
              pw.SizedBox(height: 8),

              _buildSectionTitle(
                'ARTÍCULOS ENTREGADOS',
                color: _kOrange,
                bg: _kLightOrange,
              ),
              ...sale.details
                  .map(
                    (item) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 20,
                            child: pw.Text(
                              '${item.quantity}x',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: _kOrange,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              item.productName,
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: _kTextDark,
                              ),
                            ),
                          ),
                          pw.Text(
                            '\$${item.subtotalUSD.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _kTextDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(), // <-- CLAVE: .toList() AGREGADO
              pw.SizedBox(height: 12),

              _buildTotalsBox(
                pendienteUSD,
                pendienteVES,
                color: _kOrange,
                title: 'SALDO DEUDOR',
                labelUSD: 'FALTA USD:',
                labelVES: 'FALTA VES:',
              ),
              pw.SizedBox(height: 10),

              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: _kLightOrange,
                  border: pw.Border.all(color: _kOrange, width: 1),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'CONSERVE ESTE TICKET PARA SU PAGO FUTURO.',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 7,
                      color: _kOrange,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),

              _buildFooter('Documento de control interno de deudas.'),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> generateSalesReport(
    List<Sale> sales,
    String periodName,
  ) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    double totalUSD = 0.0, totalVES = 0.0;
    double efectivoBs_usd = 0.0, efectivoBs_ves = 0.0, efectivoUsd_usd = 0.0;
    double pagoMovil_usd = 0.0,
        pagoMovil_ves = 0.0,
        puntoVenta_usd = 0.0,
        puntoVenta_ves = 0.0;
    final Map<String, Map<String, dynamic>> aggregatedItems = {};

    for (var sale in sales) {
      totalUSD += sale.totalUSD;
      totalVES += sale.totalVES;

      for (var payment in sale.payments) {
        final method = payment.method.toLowerCase();
        final amountUSD = payment.amount;
        final amountVES = amountUSD * sale.exchangeRate;

        if (method.contains('usd') || method.contains('\$')) {
          efectivoUsd_usd += amountUSD;
        } else if (method.contains('móvil') || method.contains('movil')) {
          pagoMovil_usd += amountUSD;
          pagoMovil_ves += amountVES;
        } else if (method.contains('punto') || method.contains('tarjeta')) {
          puntoVenta_usd += amountUSD;
          puntoVenta_ves += amountVES;
        } else if (!method.contains('transferencia') &&
            !method.contains('pendiente')) {
          efectivoBs_usd += amountUSD;
          efectivoBs_ves += amountVES;
        }
      }

      for (var detail in sale.details) {
        if (aggregatedItems.containsKey(detail.productId)) {
          aggregatedItems[detail.productId]!['qty'] += detail.quantity;
          aggregatedItems[detail.productId]!['total'] += detail.subtotalUSD;
        } else {
          aggregatedItems[detail.productId] = {
            'name': detail.productName,
            'qty': detail.quantity,
            'total': detail.subtotalUSD,
          };
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVENTORY',
                      style: pw.TextStyle(
                        color: _kDarkGreen,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    pw.Text(
                      'REPORTE GLOBAL DE VENTAS',
                      style: pw.TextStyle(color: _kTextGrey, fontSize: 12),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _kDarkGreen,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    'PERÍODO: ${periodName.toUpperCase()}',
                    style: pw.TextStyle(
                      color: _kWhite,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: _kDivider, thickness: 1),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: _kDivider, thickness: 1),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Inventory & POS v1.9.3',
                  style: pw.TextStyle(color: _kTextGrey, fontSize: 8),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(color: _kTextGrey, fontSize: 8),
                ),
              ],
            ),
          ],
        ),
        build: (context) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('RESUMEN DE INGRESOS POR MÉTODO'),
                      if (efectivoBs_usd > 0)
                        _buildInfoRow(
                          '• Efectivo (Bs):',
                          '\$${efectivoBs_usd.toStringAsFixed(2)}  /  Bs. ${efectivoBs_ves.toStringAsFixed(2)}',
                        ),
                      if (efectivoUsd_usd > 0)
                        _buildInfoRow(
                          '• Efectivo (\$):',
                          '\$${efectivoUsd_usd.toStringAsFixed(2)}',
                        ),
                      if (pagoMovil_usd > 0)
                        _buildInfoRow(
                          '• Pago Móvil:',
                          '\$${pagoMovil_usd.toStringAsFixed(2)}  /  Bs. ${pagoMovil_ves.toStringAsFixed(2)}',
                        ),
                      if (puntoVenta_usd > 0)
                        _buildInfoRow(
                          '• Punto de Venta:',
                          '\$${puntoVenta_usd.toStringAsFixed(2)}  /  Bs. ${puntoVenta_ves.toStringAsFixed(2)}',
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 2,
                  child: _buildTotalsBox(totalUSD, totalVES),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            _buildSectionTitle('TRANSACCIONES PROCESADAS (${sales.length})'),
            pw.Table(
              border: pw.TableBorder.all(color: _kDivider, width: 1),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _kLightGrey),
                  children:
                      ['Fecha', 'Ticket', 'Cliente', 'Método(s)', 'Total USD']
                          .map(
                            (h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                h,
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9,
                                  color: _kDarkGreen,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                ...sales.map((s) {
                  final methods = s.payments
                      .map((p) => p.method)
                      .toSet()
                      .join(', ');
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          DateFormat('dd/MM/yy HH:mm').format(s.date),
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          s.id.length > 8 ? s.id.substring(0, 8) : s.id,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          s.debtorName ?? 'Contado',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          methods,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '\$${s.totalUSD.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _kDarkGreen,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(), // <-- CLAVE: .toList() AGREGADO AQUÍ TAMIÉN
              ],
            ),
            pw.SizedBox(height: 20),

            _buildSectionTitle('INVENTARIO MOVILIZADO (ARTÍCULOS VENDIDOS)'),
            pw.Table(
              border: pw.TableBorder.all(color: _kDivider, width: 1),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _kLightGrey),
                  children: ['Cant.', 'Producto', 'Total Generado']
                      .map(
                        (h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                              color: _kDarkGreen,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                ...aggregatedItems.values
                    .map(
                      (item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '${item['qty']}',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              item['name'],
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              '\$${(item['total'] as double).toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: _kDarkGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(), // <-- CLAVE: .toList() AGREGADO AQUÍ
              ],
            ),
          ];
        },
      ),
    );
    return pdf.save();
  }
}

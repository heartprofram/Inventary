import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../features/sales/domain/sale.dart';

// ─── Paleta de colores corporativa ───────────────────────────────────────────
const _kPrimary      = PdfColor.fromInt(0xFF00796B); // Teal 700
const _kPrimaryLight = PdfColor.fromInt(0xFFB2DFDB); // Teal 100
const _kAccent       = PdfColor.fromInt(0xFF004D40); // Teal 900
const _kSuccess      = PdfColor.fromInt(0xFF2E7D32); // Green 800
const _kWarning      = PdfColor.fromInt(0xFFF57C00); // Orange 700
const _kGrey100      = PdfColor.fromInt(0xFFF5F5F5);
const _kGrey300      = PdfColor.fromInt(0xFFE0E0E0);
const _kGrey600      = PdfColor.fromInt(0xFF757575);
const _kGrey800      = PdfColor.fromInt(0xFF424242);
const _kWhite        = PdfColors.white;

class PdfInvoiceGenerator {
  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS DE ESTILO
  // ══════════════════════════════════════════════════════════════════════════

  static pw.TextStyle _h2({PdfColor? color}) => pw.TextStyle(
    fontSize: 15, fontWeight: pw.FontWeight.bold,
    color: color ?? _kAccent,
  );

  static pw.TextStyle _h3({PdfColor? color}) => pw.TextStyle(
    fontSize: 11, fontWeight: pw.FontWeight.bold,
    color: color ?? _kGrey800,
  );

  static pw.TextStyle _body({PdfColor? color, double size = 9}) =>
    pw.TextStyle(fontSize: size, color: color ?? _kGrey800);

  static pw.TextStyle _mono({PdfColor? color, double size = 9}) =>
    pw.TextStyle(fontSize: size, color: color ?? _kGrey800);

  static pw.TextStyle _tableHeader() => pw.TextStyle(
    fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kWhite,
  );

  /// Cabecera decorativa reutilizable para los documentos.
  static pw.Widget _buildDocumentHeader({
    required String title,
    required String subtitle,
    String? badge,
    PdfColor badgeColor = _kPrimary,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const pw.BoxDecoration(color: _kPrimary),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('INVENTARY & POS v1.9.3', style: pw.TextStyle(
                    fontSize: 9, color: _kPrimaryLight,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                  )),
                  pw.SizedBox(height: 2),
                  pw.Text(title, style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold,
                    color: _kWhite,
                  )),
                ],
              ),
              if (badge != null)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: badgeColor,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: _kWhite, width: 1.5),
                  ),
                  child: pw.Text(badge, style: pw.TextStyle(
                    color: _kWhite, fontWeight: pw.FontWeight.bold, fontSize: 9,
                  )),
                ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: const pw.BoxDecoration(color: _kPrimaryLight),
          child: pw.Text(subtitle, style: _body(color: _kAccent, size: 8.5)),
        ),
      ],
    );
  }



  /// Fila de datos (etiqueta + valor) para resúmenes.
  static pw.Widget _kv(String label, String value, {
    bool bold = false, PdfColor? valueColor, double size = 9,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: _body(color: _kGrey600, size: size)),
          pw.Text(value, style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? _kGrey800,
          )),
        ],
      ),
    );
  }

  /// Separador horizontal sutil.
  static pw.Widget _divider({PdfColor? color}) =>
    pw.Divider(height: 1, thickness: 0.5, color: color ?? _kGrey300);

  /// Footer para facturas de ticket (80mm).
  static pw.Widget _ticketFooter(String msg) => pw.Column(
    children: [
      pw.SizedBox(height: 10),
      _divider(),
      pw.SizedBox(height: 6),
      pw.Center(child: pw.Text(msg, style: _body(color: _kGrey600, size: 8))),
      pw.SizedBox(height: 4),
      pw.Center(child: pw.Text(
        'Inventary & POS v1.9.3  •  ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
        style: _body(color: _kGrey600, size: 7),
      )),
    ],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // FACTURA / RECIBO DE VENTA (roll80)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateInvoice(Sale sale) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    final fmt = DateFormat('dd/MM/yyyy  HH:mm');

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Encabezado ──────────────────────────────────────────────
            pw.Center(child: pw.Text('INVENTARY', style: pw.TextStyle(
              fontSize: 14, fontWeight: pw.FontWeight.bold,
              color: _kAccent, letterSpacing: 1.5,
            ))),
            pw.SizedBox(height: 2),
            pw.Center(child: pw.Text('RECIBO DE VENTA', style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kPrimary,
            ))),
            pw.SizedBox(height: 8),
            _divider(color: _kPrimary),
            pw.SizedBox(height: 6),

            // ── Datos del comprobante ────────────────────────────────────
            _kv('Nro:', sale.id, bold: true, size: 8),
            _kv('Fecha:', fmt.format(sale.date), size: 8),
            _kv('Tasa BCV:', '${sale.exchangeRate.toStringAsFixed(2)} VES/USD', size: 8),
            if ((sale.debtorName ?? '').isNotEmpty)
              _kv('Cliente:', sale.debtorName!, bold: true, size: 8),

            pw.SizedBox(height: 8),
            _divider(),
            pw.SizedBox(height: 4),

            // ── Encabezado de tabla ──────────────────────────────────────
            pw.Container(
              color: _kGrey100,
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: pw.Row(children: [
                pw.Expanded(flex: 4, child: pw.Text('Producto', style: _h3())),
                pw.Expanded(flex: 1, child: pw.Text('Ctd', textAlign: pw.TextAlign.center, style: _h3())),
                pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: _h3())),
              ]),
            ),
            _divider(),

            // ── Ítems ────────────────────────────────────────────────────
            ...sale.details.map((item) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _kGrey300, width: 0.3)),
              ),
              child: pw.Row(children: [
                pw.Expanded(flex: 4, child: pw.Text(item.productName, style: _body(size: 8), maxLines: 2)),
                pw.Expanded(flex: 1, child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center, style: _body(size: 8))),
                pw.Expanded(flex: 2, child: pw.Text('\$${item.subtotalUSD.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: _mono(size: 8))),
              ]),
            )),

            pw.SizedBox(height: 4),
            _divider(color: _kPrimary),

            // ── Totales ──────────────────────────────────────────────────
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: _kGrey100,
                border: pw.Border.all(color: _kGrey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(children: [
                _kv('Subtotal USD:', '\$${sale.totalUSD.toStringAsFixed(2)}', size: 8),
                _kv('Total VES:', 'Bs. ${sale.totalVES.toStringAsFixed(2)}', size: 8),
                _divider(),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL USD:', style: _h2(color: _kAccent)),
                    pw.Text('\$${sale.totalUSD.toStringAsFixed(2)}', style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold, color: _kSuccess,
                    )),
                  ],
                ),
              ]),
            ),

            // ── Métodos de pago ──────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(7),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _kGrey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('MÉTODO DE PAGO', style: _body(color: _kPrimary, size: 7.5)),
                  pw.SizedBox(height: 4),
                  ...sale.payments.map((p) => _kv(
                    '• ${p.method}:',
                    '\$${p.amount.toStringAsFixed(2)}',
                    bold: true, size: 8.5, valueColor: _kSuccess,
                  )),
                ],
              ),
            ),

            _ticketFooter('¡Gracias por su compra!'),
          ],
        );
      },
    ));

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTA DE CUENTA POR COBRAR (roll80)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateSimpleInvoice(Sale sale) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    final fmt = DateFormat('dd/MM/yyyy  HH:mm');

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Encabezado ──────────────────────────────────────────────
            pw.Center(child: pw.Text('INVENTARY', style: pw.TextStyle(
              fontSize: 14, fontWeight: pw.FontWeight.bold,
              color: _kAccent, letterSpacing: 1.5,
            ))),
            pw.SizedBox(height: 2),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              color: _kWarning,
              child: pw.Center(child: pw.Text('CUENTA POR COBRAR', style: pw.TextStyle(
                fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kWhite,
              ))),
            ),
            pw.SizedBox(height: 8),
            _divider(color: _kWarning),
            pw.SizedBox(height: 6),

            _kv('Nro:', sale.id, bold: true, size: 8),
            _kv('Fecha:', fmt.format(sale.date), size: 8),
            _kv('Deudor:', sale.debtorName ?? 'N/A', bold: true, size: 8, valueColor: _kWarning),

            pw.SizedBox(height: 8),
            _divider(),
            pw.SizedBox(height: 4),

            pw.Container(
              color: _kGrey100,
              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: pw.Row(children: [
                pw.Expanded(flex: 4, child: pw.Text('Producto', style: _h3())),
                pw.Expanded(flex: 1, child: pw.Text('Ctd', textAlign: pw.TextAlign.center, style: _h3())),
                pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: _h3())),
              ]),
            ),
            _divider(),

            ...sale.details.map((item) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _kGrey300, width: 0.3)),
              ),
              child: pw.Row(children: [
                pw.Expanded(flex: 4, child: pw.Text(item.productName, style: _body(size: 8), maxLines: 2)),
                pw.Expanded(flex: 1, child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center, style: _body(size: 8))),
                pw.Expanded(flex: 2, child: pw.Text('\$${item.subtotalUSD.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: _mono(size: 8))),
              ]),
            )),

            pw.SizedBox(height: 4),
            _divider(color: _kWarning),

            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFF8E1), // Amber 50
                border: pw.Border.all(color: _kWarning, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(children: [
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('MONTO ADEUDADO:', style: _h2(color: _kWarning)),
                  pw.Text('\$${sale.totalUSD.toStringAsFixed(2)}', style: pw.TextStyle(
                    fontSize: 15, fontWeight: pw.FontWeight.bold, color: _kWarning,
                  )),
                ]),
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text('⚠  PAGO PENDIENTE', style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kWarning,
                ))),
              ]),
            ),

            _ticketFooter('Este documento es un comprobante de deuda.'),
          ],
        );
      },
    ));

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CIERRE Z - REPORTE DE CAJA (roll80)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateZReport(
    List<Sale> sales, double totalUSD, double totalVES,
  ) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    final now = DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy  HH:mm');

    // ── Calcular resúmenes de pago por método ──────────────────────────────
    final Map<String, double> paymentTotals = {};
    for (final sale in sales) {
      for (final p in sale.payments) {
        paymentTotals[p.method] = (paymentTotals[p.method] ?? 0) + p.amount;
      }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Encabezado ──────────────────────────────────────────────
            pw.Center(child: pw.Text('INVENTARY', style: pw.TextStyle(
              fontSize: 14, fontWeight: pw.FontWeight.bold,
              color: _kAccent, letterSpacing: 1.5,
            ))),
            pw.SizedBox(height: 2),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              color: _kAccent,
              child: pw.Center(child: pw.Text('REPORTE CIERRE DE CAJA', style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kWhite, letterSpacing: 1,
              ))),
            ),
            pw.SizedBox(height: 6),
            _kv('Fecha de cierre:', fmt.format(now), bold: true, size: 8),
            pw.SizedBox(height: 8),

            // ── Sección 1: Resumen de Ventas ─────────────────────────────
            pw.Container(
              color: _kGrey100,
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              child: pw.Text('▸  RESUMEN DE VENTAS', style: _h3(color: _kPrimary)),
            ),
            pw.SizedBox(height: 4),

            // Ventas detalladas
            ...sales.expand((sale) => [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _kPrimary, width: 0.5))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('ID: ${sale.id.length > 10 ? sale.id.substring(sale.id.length - 8) : sale.id} | ${DateFormat('HH:mm').format(sale.date)}', style: _body(size: 8, color: _kAccent).copyWith(fontWeight: pw.FontWeight.bold)),
                    pw.Text('\$${sale.totalUSD.toStringAsFixed(2)} / Bs. ${sale.totalVES.toStringAsFixed(2)}', style: _mono(size: 8, color: _kSuccess).copyWith(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4, top: 2, bottom: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: sale.details.map((item) => pw.Row(
                    children: [
                      pw.Text('• ${item.quantity}x ', style: _body(size: 7.5, color: _kGrey600)),
                      pw.Expanded(child: pw.Text(item.productName, style: _body(size: 7.5))),
                      pw.Text('\$${item.subtotalUSD.toStringAsFixed(2)}', style: _mono(size: 7.5, color: _kGrey600)),
                    ]
                  )).toList(),
                ),
              ),
            ]),
            pw.SizedBox(height: 4),
            _divider(color: _kGrey300),
            _kv('Total de transacciones:', '${sales.length}', bold: true, size: 8),

            pw.SizedBox(height: 8),

            // ── Sección 2: Resumen de Pagos ──────────────────────────────
            pw.Container(
              color: _kGrey100,
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              child: pw.Text('▸  RESUMEN POR MÉTODO DE PAGO', style: _h3(color: _kPrimary)),
            ),
            pw.SizedBox(height: 4),
            ...paymentTotals.entries.map((e) => _kv(
              '• ${e.key}:', '\$${e.value.toStringAsFixed(2)}',
              bold: true, size: 8.5, valueColor: _kSuccess,
            )),

            pw.SizedBox(height: 8),
            _divider(color: _kAccent),

            // ── Sección 3: Estado Final de Caja ──────────────────────────
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _kGrey100,
                border: pw.Border.all(color: _kAccent, width: 1),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(children: [
                pw.Center(child: pw.Text('TOTALES DEL PERÍODO', style: pw.TextStyle(
                  fontSize: 8, fontWeight: pw.FontWeight.bold,
                  color: _kAccent, letterSpacing: 1,
                ))),
                pw.SizedBox(height: 6),
                _divider(),
                pw.SizedBox(height: 6),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL USD:', style: _h2(color: _kAccent)),
                  pw.Text('\$${totalUSD.toStringAsFixed(2)}', style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold, color: _kSuccess,
                  )),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL VES:', style: _h2(color: _kAccent)),
                  pw.Text('Bs. ${totalVES.toStringAsFixed(2)}', style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold, color: _kSuccess,
                  )),
                ]),
              ]),
            ),

            _ticketFooter('Cierre de caja completado — ${fmt.format(now)}'),
          ],
        );
      },
    ));

    return pdf.save();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTE DE VENTAS POR PERÍODO (A4)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<Uint8List> generateSalesReport(
    List<Sale> sales, String periodName,
  ) async {
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold));
    final totalUSD = sales.fold(0.0, (s, sale) => s + sale.totalUSD);
    final totalVES = sales.fold(0.0, (s, sale) => s + sale.totalVES);
    final now = DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy  HH:mm');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      header: (context) => _buildDocumentHeader(
        title: 'REPORTE DE VENTAS',
        subtitle:
            'Período: $periodName  •  Generado: ${fmt.format(now)}  •  ${sales.length} transacciones',
        badge: periodName.toUpperCase(),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _kGrey300, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Inventary & POS v1.9.3  •  Reporte confidencial', style: _body(color: _kGrey600, size: 7.5)),
            pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: _body(color: _kGrey600, size: 7.5)),
          ],
        ),
      ),
      build: (context) {
        return [
          pw.SizedBox(height: 16),

          // ── Tabla de ventas ─────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Table(
              border: pw.TableBorder.all(color: _kGrey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),   // Fecha
                1: const pw.FlexColumnWidth(1.5), // Cliente
                2: const pw.FlexColumnWidth(1),   // Tasa
                3: const pw.FlexColumnWidth(1.2), // USD
                4: const pw.FlexColumnWidth(1.2), // VES
              },
              children: [
                // Encabezado
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _kPrimary),
                  children: [
                    'Fecha / Hora', 'Cliente', 'Tasa VES', 'Total USD', 'Total VES',
                  ].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text(h, style: _tableHeader()),
                  )).toList(),
                ),
                // Filas de datos
                ...sales.asMap().entries.map((entry) {
                  final i = entry.key;
                  final sale = entry.value;
                  final bg = i.isEven ? _kWhite : _kGrey100;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _tableCell(fmt.format(sale.date), align: pw.TextAlign.left),
                      _tableCell(sale.debtorName ?? 'Contado'),
                      _tableCell(sale.exchangeRate.toStringAsFixed(2), align: pw.TextAlign.right),
                      _tableCell('\$${sale.totalUSD.toStringAsFixed(2)}', align: pw.TextAlign.right, color: _kSuccess, bold: true),
                      _tableCell('Bs. ${sale.totalVES.toStringAsFixed(2)}', align: pw.TextAlign.right),
                    ],
                  );
                }),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── Caja de totalizaciones ──────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                gradient: const pw.LinearGradient(
                  colors: [_kPrimaryLight, _kWhite],
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _kPrimary, width: 1.5),
              ),
              child: pw.Column(children: [
                // Título de resumen
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('RESUMEN DEL PERÍODO', style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold,
                      color: _kAccent, letterSpacing: 1,
                    )),
                    pw.SizedBox(height: 2),
                    pw.Text('$periodName  —  ${sales.length} ventas procesadas', style: _body(color: _kGrey600, size: 8.5)),
                  ]),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: _kPrimary,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text('${sales.length} ventas', style: pw.TextStyle(
                      color: _kWhite, fontSize: 9, fontWeight: pw.FontWeight.bold,
                    )),
                  ),
                ]),

                pw.SizedBox(height: 14),
                pw.Divider(color: _kPrimary, thickness: 0.8),
                pw.SizedBox(height: 14),

                // Totales
                pw.Row(children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: _kWhite,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: _kGrey300),
                      ),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text('INGRESOS USD', style: _body(color: _kGrey600, size: 8)),
                        pw.SizedBox(height: 4),
                        pw.Text('\$${totalUSD.toStringAsFixed(2)}', style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold, color: _kSuccess,
                        )),
                      ]),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: _kWhite,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: _kGrey300),
                      ),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text('INGRESOS VES', style: _body(color: _kGrey600, size: 8)),
                        pw.SizedBox(height: 4),
                        pw.Text('Bs. ${totalVES.toStringAsFixed(2)}', style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold, color: _kAccent,
                        )),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),
          ),

          pw.SizedBox(height: 32),
        ];
      },
    ));

    return pdf.save();
  }

  /// Helper para celdas de tabla A4.
  static pw.Widget _tableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(
        fontSize: 8.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? _kGrey800,
      )),
    );
  }
}
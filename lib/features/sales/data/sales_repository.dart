import '../../../core/services/google_api_service.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../../core/constants/app_constants.dart';
import '../domain/sale.dart';
import '../../inventory/data/product_repository.dart';

class SalesRepository {
  final GoogleApiService googleApi;
  final ProductRepository productRepository;

  SalesRepository({required this.googleApi, required this.productRepository});

  Future<void> processSale(Sale sale) async {
    try {
      // 1. Guardar la venta en Google Sheets (hoja "Ventas")
      final valueRange = sheets.ValueRange(
        values: [[
          sale.id,
          sale.date.toIso8601String(),
          sale.totalUSD,
          sale.totalVES,
          sale.exchangeRate,
          'Local',
          sale.paymentMethodLabel,
        ]],
      );

      await googleApi.sheetsApi.spreadsheets.values.append(
        valueRange,
        AppConstants.spreadSheetId,
        'Ventas!A:G',
        valueInputOption: 'USER_ENTERED',
      );

      // 1.5 Guardar los detalles en DetalleVentas
      for (final detail in sale.details) {
        final detailRange = sheets.ValueRange(
          values: [[
            sale.id,
            detail.productId,
            detail.productName,
            detail.quantity,
            detail.unitPriceUSD,
            detail.subtotalUSD,
          ]]
        );
        await googleApi.sheetsApi.spreadsheets.values.append(
          detailRange,
          AppConstants.spreadSheetId,
          'DetalleVentas!A:F',
          valueInputOption: 'USER_ENTERED',
        );
      }

      // 2. Descontar inventario
      final products = await productRepository.getProducts();
      for (final detail in sale.details) {
        final idx = products.indexWhere((p) => p.id == detail.productId);
        if (idx >= 0) {
          final currentStock = products[idx].stockQuantity;
          final newStock = (currentStock - detail.quantity).clamp(0, 999999);
          await productRepository.updateStock(detail.productId, newStock);
        }
      }
    } catch (e) {
      throw Exception('Error al procesar la venta: $e');
    }
  }

  Future<List<Sale>> getSalesHistory() async {
    try {
      // 1. Fetch Ventas
      final ventasResp = await googleApi.sheetsApi.spreadsheets.values.get(
        AppConstants.spreadSheetId,
        'Ventas!A2:G',
      );
      final ventasRows = ventasResp.values ?? [];

      // 2. Fetch DetalleVentas
      final detallesResp = await googleApi.sheetsApi.spreadsheets.values.get(
        AppConstants.spreadSheetId,
        'DetalleVentas!A2:F',
      );
      final detallesRows = detallesResp.values ?? [];

      final Map<String, List<SaleDetail>> detailsMap = {};
      for (var row in detallesRows) {
        if (row.length >= 6) {
          final saleId = row[0].toString();
          final detail = SaleDetail(
            productId: row[1].toString(),
            productName: row[2].toString(),
            quantity: int.tryParse(row[3].toString()) ?? 0,
            unitPriceUSD: double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 0.0,
          );
          if (!detailsMap.containsKey(saleId)) {
            detailsMap[saleId] = [];
          }
          detailsMap[saleId]!.add(detail);
        }
      }

      final List<Sale> sales = [];
      for (var row in ventasRows) {
        // Asumiendo formato: ['ID Venta', 'Fecha', 'Total USD', 'Total VES', 'Tasa Cambio', 'PDF', 'Metodo de Pago']
        if (row.length >= 5) {
          final saleId = row[0].toString();
          final dateStr = row[1].toString();
          final totalUSD = double.tryParse(row[2].toString().replaceAll(',', '.')) ?? 0.0;
          final totalVES = double.tryParse(row[3].toString().replaceAll(',', '.')) ?? 0.0;
          final exchangeRate = double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 1.0;
          final paymentMethod = row.length >= 7 ? row[6].toString() : 'Efectivo'; // Default
          
          final details = detailsMap[saleId] ?? [];
          
          final sale = Sale(
            id: saleId,
            date: DateTime.tryParse(dateStr) ?? DateTime.now(),
            exchangeRate: exchangeRate,
            details: details,
            paymentMethod: paymentMethod,
          );
          sale.overrideTotals(totalUSD, totalVES);
          sales.add(sale);
        }
      }
      sales.sort((a, b) => b.date.compareTo(a.date));
      return sales;
    } catch (e) {
      throw Exception('Error al obtener historial de ventas: $e');
    }
  }

  Future<void> updateSale(Sale oldSale, Sale newSale) async {
    try {
      await deleteSale(oldSale);
      await processSale(newSale); // Se inserta como nueva pero mantiene su ID y Fecha, el sort() la ubicará bien.
    } catch (e) {
      throw Exception('Error al actualizar la venta: $e');
    }
  }

  Future<void> deleteSale(Sale sale) async {
    try {
      // 1. Devolver el stock de los productos vendidos
      final products = await productRepository.getProducts();
      for (final detail in sale.details) {
        final idx = products.indexWhere((p) => p.id == detail.productId);
        if (idx >= 0) {
          final currentStock = products[idx].stockQuantity;
          final newStock = currentStock + detail.quantity; // Devolver al stock
          await productRepository.updateStock(detail.productId, newStock);
        }
      }

      // 2. Obtener los IDs de las hojas
      final spreadsheet = await googleApi.sheetsApi.spreadsheets.get(AppConstants.spreadSheetId);
      final ventasSheetId = spreadsheet.sheets?.firstWhere((s) => s.properties?.title == 'Ventas', orElse: () => sheets.Sheet()).properties?.sheetId;
      final detalleVentasSheetId = spreadsheet.sheets?.firstWhere((s) => s.properties?.title == 'DetalleVentas', orElse: () => sheets.Sheet()).properties?.sheetId;

      if (ventasSheetId == null || detalleVentasSheetId == null) {
        throw Exception('No se encontraron las hojas Ventas o DetalleVentas');
      }

      // 3. Buscar índices en Ventas
      final ventasResp = await googleApi.sheetsApi.spreadsheets.values.get(
        AppConstants.spreadSheetId,
        'Ventas!A:A',
      );
      final ventasRows = ventasResp.values ?? [];
      int startIndexVenta = -1;
      for (int i = 0; i < ventasRows.length; i++) {
        if (ventasRows[i].isNotEmpty && ventasRows[i][0].toString() == sale.id) {
          startIndexVenta = i;
          break;
        }
      }

      // 4. Buscar índices en DetalleVentas
      final detallesResp = await googleApi.sheetsApi.spreadsheets.values.get(
        AppConstants.spreadSheetId,
        'DetalleVentas!A:F',
      );
      final detallesRows = detallesResp.values ?? [];
      
      List<int> detailRowsIndices = [];
      for (int i = 0; i < detallesRows.length; i++) {
        if (detallesRows[i].isNotEmpty && detallesRows[i][0].toString() == sale.id) {
          detailRowsIndices.add(i);
        }
      }

      // 5. Preparar BatchUpdate para borrar las filas
      detailRowsIndices.sort((a, b) => b.compareTo(a));

      final requests = <sheets.Request>[];

      for (int rowIndex in detailRowsIndices) {
        requests.add(sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: detalleVentasSheetId,
              dimension: 'ROWS',
              startIndex: rowIndex,
              endIndex: rowIndex + 1,
            ),
          ),
        ));
      }

      if (startIndexVenta != -1) {
        requests.add(sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: ventasSheetId,
              dimension: 'ROWS',
              startIndex: startIndexVenta,
              endIndex: startIndexVenta + 1,
            ),
          ),
        ));
      }

      if (requests.isNotEmpty) {
        final batchUpdate = sheets.BatchUpdateSpreadsheetRequest(requests: requests);
        await googleApi.sheetsApi.spreadsheets.batchUpdate(batchUpdate, AppConstants.spreadSheetId);
      }

    } catch (e) {
      throw Exception('Error al eliminar la venta: $e');
    }
  }
}

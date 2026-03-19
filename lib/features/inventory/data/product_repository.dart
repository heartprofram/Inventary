import '../../../core/services/google_api_service.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../../core/constants/app_constants.dart';
import '../domain/product.dart';

class ProductRepository {
  final GoogleApiService googleApi;

  ProductRepository({required this.googleApi});

  // Leer todos los productos del servidor proxy
  Future<List<Product>> getProducts() async {
    try {
      final response = await googleApi.sheetsApi.spreadsheets.values.get(
        AppConstants.spreadSheetId,
        'Productos!A2:G',
      );
      final rows = response.values ?? [];
      return rows.map((row) => _fromRow(row)).toList();
    } catch (e) {
      throw Exception('Error al obtener productos: $e');
    }
  }

  // Agregar un producto
  Future<void> addProduct(Product product) async {
    try {
      final valueRange = sheets.ValueRange(values: [_toRow(product)]);
      await googleApi.sheetsApi.spreadsheets.values.append(
        valueRange,
        AppConstants.spreadSheetId,
        'Productos!A:G',
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      throw Exception('Error al guardar el producto: $e');
    }
  }

  // Actualizar stock de un producto
  Future<void> updateStock(String productId, int newStock) async {
    try {
      // 1. Obtener todas las filas para encontrar el índice
      final response = await googleApi.sheetsApi.spreadsheets.values.get(
        AppConstants.spreadSheetId,
        'Productos!A2:G',
      );
      final rows = response.values ?? [];

      int rowIndex = -1;
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.isNotEmpty && row[0].toString() == productId) {
          rowIndex = i + 2; // +2: fila 1 es header, base 1 de Sheets
          break;
        }
      }

      if (rowIndex == -1) {
        throw Exception('Producto no encontrado');
      }

      // 2. Actualizar sólo la celda del Stock (columna F)
      final updateRange = sheets.ValueRange(values: [[newStock]]);
      await googleApi.sheetsApi.spreadsheets.values.update(
        updateRange,
        AppConstants.spreadSheetId,
        'Productos!F$rowIndex',
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      throw Exception('Error al actualizar el stock: $e');
    }
  }

  // Mappers
  Product _fromRow(List<dynamic> row) {
    String safeString(int i) => (row.length > i) ? row[i].toString() : '';
    double safeDouble(int i) => (row.length > i) ? double.tryParse(row[i].toString().replaceAll(',', '')) ?? 0.0 : 0.0;
    int safeInt(int i) => (row.length > i) ? int.tryParse(row[i].toString()) ?? 0 : 0;

    return Product(
      id: safeString(0),
      name: safeString(1),
      description: safeString(2),
      costPriceUSD: safeDouble(3),
      salePriceUSD: safeDouble(4),
      stockQuantity: safeInt(5),
      barCode: safeString(6),
    );
  }

  List<Object?> _toRow(Product p) => [
    p.id, p.name, p.description,
    p.costPriceUSD, p.salePriceUSD,
    p.stockQuantity, p.barCode,
  ];
}

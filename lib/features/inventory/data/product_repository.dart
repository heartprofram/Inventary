import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../../core/services/google_api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/product.dart';

class ProductRepository {
  final Dio dio;
  final GoogleApiService googleApi;
  final String baseUrl = 'http://localhost:8081/api';

  ProductRepository({required this.dio, required this.googleApi});

  Future<List<Product>> getProducts() async {
    List<dynamic> rows = [];
    final box = Hive.box('inventory_box');

    try {
      if (kIsWeb) {
        final response = await dio.get('$baseUrl/productos')
            .timeout(const Duration(seconds: 4));
        rows = response.data ?? [];
      } else {
        final response = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Productos!A2:G',
        ).timeout(const Duration(seconds: 5)); // Un poco más para Google Sheets
        rows = response.values ?? [];
      }
      
      // Si la red fue exitosa, actualizamos el caché local
      await box.put('products_cache', rows);
    } catch (networkError) {
      debugPrint('[Offline] Error de red en ${kIsWeb ? 'Web' : 'Android'}, cargando caché: $networkError');
      // CARGA OFFLINE: Recuperar los últimos datos guardados en Hive
      rows = box.get('products_cache', defaultValue: []) as List<dynamic>;
    }

    try {
      return rows.where((row) => row.length >= 6).map((row) {
        return Product(
          id: row[0].toString(),
          name: row[1].toString(),
          description: row.length > 2 ? row[2].toString() : '',
          costPriceUSD: double.tryParse(row[3].toString().replaceAll(',', '.')) ?? 0.0,
          salePriceUSD: double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 0.0,
          stockQuantity: int.tryParse(row[5].toString()) ?? 0,
          barCode: row.length > 6 ? row[6].toString() : '',
        );
      }).toList();
    } catch (e) {
      throw Exception('Error al procesar datos de productos: $e');
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      final row = [
        product.id,
        product.name,
        product.description,
        product.costPriceUSD,
        product.salePriceUSD,
        product.stockQuantity,
        product.barCode,
      ];

      if (kIsWeb) {
        await dio.post('$baseUrl/productos', data: {'row': row});
      } else {
        final valueRange = sheets.ValueRange(values: [row]);
        await googleApi.sheetsApi.spreadsheets.values.append(
          valueRange,
          AppConstants.spreadSheetId,
          'Productos!A:G',
          valueInputOption: 'USER_ENTERED',
        );
      }
    } catch (e) {
      throw Exception('Error al agregar producto: $e');
    }
  }

  Future<void> updateStock(String productId, int newStock) async {
    try {
      if (kIsWeb) {
        // En Web, el servidor Python ya maneja la búsqueda de fila
        final productsResp = await dio.get('$baseUrl/productos');
        final rows = productsResp.data as List<dynamic>;
        int rowIndex = -1;
        for (int i = 0; i < rows.length; i++) {
          if (rows[i].isNotEmpty && rows[i][0].toString() == productId) {
              rowIndex = i + 2; 
              break;
          }
        }
        if (rowIndex != -1) {
            await dio.put('$baseUrl/productos/stock', data: {
                'range': 'Productos!F$rowIndex',
                'value': newStock
            });
        }
      } else {
        // En Nativo, debemos buscar la fila localmente
        final response = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Productos!A2:A', // Solo necesitamos la columna de IDs
        );
        final rows = response.values ?? [];
        int rowIndex = -1;
        for (int i = 0; i < rows.length; i++) {
          if (rows[i].isNotEmpty && rows[i][0].toString() == productId) {
            rowIndex = i + 2;
            break;
          }
        }
        
        if (rowIndex != -1) {
          final valueRange = sheets.ValueRange(values: [[newStock]]);
          await googleApi.sheetsApi.spreadsheets.values.update(
            valueRange,
            AppConstants.spreadSheetId,
            'Productos!F$rowIndex',
            valueInputOption: 'USER_ENTERED',
          );
        }
      }
    } catch (e) {
      throw Exception('Error al actualizar stock: $e');
    }
  }
  
  Future<void> updateProduct(Product product) async {
    try {
      final rowData = [
        product.id, product.name, product.description,
        product.costPriceUSD, product.salePriceUSD,
        product.stockQuantity, product.barCode
      ];

      if (kIsWeb) {
        final productsResp = await dio.get('$baseUrl/productos');
        final rows = productsResp.data as List<dynamic>;
        int rowIndex = -1;
        for (int i = 0; i < rows.length; i++) {
          if (rows[i].isNotEmpty && rows[i][0].toString() == product.id) {
              rowIndex = i + 2; 
              break;
          }
        }
        if (rowIndex != -1) {
            await dio.put('$baseUrl/productos/update', data: {
                'range': 'Productos!A$rowIndex:G$rowIndex',
                'row': rowData
            });
        }
      } else {
        final response = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Productos!A2:A',
        );
        final rows = response.values ?? [];
        int rowIndex = -1;
        for (int i = 0; i < rows.length; i++) {
          if (rows[i].isNotEmpty && rows[i][0].toString() == product.id) {
            rowIndex = i + 2;
            break;
          }
        }

        if (rowIndex != -1) {
          final valueRange = sheets.ValueRange(values: [rowData]);
          await googleApi.sheetsApi.spreadsheets.values.update(
            valueRange,
            AppConstants.spreadSheetId,
            'Productos!A$rowIndex:G$rowIndex',
            valueInputOption: 'USER_ENTERED',
          );
        }
      }
    } catch (e) {
      throw Exception('Error al actualizar producto: $e');
    }
  }
}
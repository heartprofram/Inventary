import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../../core/services/google_api_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/product.dart';

// SOLUCIÓN: IMPORT DE HIVE ELIMINADO

class ProductRepository {
  final Dio dio;
  final GoogleApiService googleApi;
  final LocalStorageService localStorageService;
  final String baseUrl = 'http://localhost:8081/api';

  ProductRepository({
    required this.dio,
    required this.googleApi,
    required this.localStorageService,
  });

  Future<List<Product>> getProducts() async {
    List<dynamic> rows = [];
    const String cacheKey = 'products_cache';

    try {
      if (kIsWeb) {
        final resp = await dio.get('$baseUrl/productos').timeout(const Duration(seconds: 5));
        rows = resp.data ?? [];
      } else {
        final resp = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Productos!A2:G',
        ).timeout(const Duration(seconds: 12));
        rows = resp.values ?? [];
      }
      
      if (rows.isNotEmpty) {
        // SOLUCIÓN: Usar servicio inyectado
        await localStorageService.saveCache('inventory_box', cacheKey, rows);
      }
    } catch (e) {
      debugPrint('[ProductRepo] Red fallida, usando caché local.');
      // SOLUCIÓN: Usar servicio inyectado
      rows = await localStorageService.getCache('inventory_box', cacheKey, defaultValue: []) as List<dynamic>;
    }

    return rows.where((r) => r.length >= 6).map((r) => Product(
      id: r[0].toString(),
      name: r[1].toString(),
      description: r.length > 2 ? r[2].toString() : '',
      costPriceUSD: double.tryParse(r[3].toString().replaceAll(',', '.')) ?? 0.0,
      salePriceUSD: double.tryParse(r[4].toString().replaceAll(',', '.')) ?? 0.0,
      stockQuantity: int.tryParse(r[5].toString()) ?? 0,
      barCode: r.length > 6 ? r[6].toString() : '',
    )).toList();
  }

  Future<void> updateStock(String productId, int newStock, {bool isSyncing = false}) async {
    try {
      if (kIsWeb) {
        // Lógica de red simplificada para el ejemplo
        await dio.put('$baseUrl/productos/stock', data: {'productId': productId, 'value': newStock});
      } else {
        final response = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId, 'Productos!A2:A',
        );
        final rows = response.values ?? [];
        int index = rows.indexWhere((r) => r.isNotEmpty && r[0].toString() == productId);
        
        if (index != -1) {
          await googleApi.sheetsApi.spreadsheets.values.update(
            sheets.ValueRange(values: [[newStock]]),
            AppConstants.spreadSheetId,
            'Productos!F${index + 2}',
            valueInputOption: 'USER_ENTERED',
          );
        }
      }
      await _updateLocalCacheStock(productId, newStock);
    } catch (e) {
      if (!isSyncing) {
        // SOLUCIÓN: Encolar mediante servicio
        await localStorageService.addPendingInventoryUpdate(productId, newStock);
        await _updateLocalCacheStock(productId, newStock);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _updateLocalCacheStock(String productId, int newStock) async {
    const String key = 'products_cache';
    final products = await localStorageService.getCache('inventory_box', key, defaultValue: []) as List<dynamic>;
    
    for (int i = 0; i < products.length; i++) {
      final row = List<dynamic>.from(products[i] as List);
      if (row.isNotEmpty && row[0].toString() == productId) {
        if (row.length > 5) {
          row[5] = newStock;
          products[i] = row;
          await localStorageService.saveCache('inventory_box', key, products);
          break;
        }
      }
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
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: [row]),
          AppConstants.spreadSheetId,
          'Productos!A:G',
          valueInputOption: 'USER_ENTERED',
        );
      }
    } catch (e) {
      throw Exception('Error al agregar producto: $e');
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

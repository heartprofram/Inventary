import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../../core/services/google_api_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/sale.dart';
import '../domain/entities/payment.dart';
import '../../inventory/data/product_repository.dart';

class SalesRepository {
  final Dio dio;
  final GoogleApiService googleApi;
  final ProductRepository productRepository;
  final LocalStorageService localStorageService;
  final String baseUrl = 'http://localhost:8081/api';

  SalesRepository({
    required this.dio, 
    required this.googleApi,
    required this.productRepository,
    required this.localStorageService,
  });

  Future<void> processSale(Sale sale) async {
    try {
      final ventaRow = [
        sale.id,
        sale.date.toIso8601String(),
        sale.totalUSD,
        sale.totalVES,
        sale.exchangeRate,
        ' ', 
        jsonEncode(sale.payments.map((p) => p.toJson()).toList()),
        sale.debtorName != null && sale.debtorName!.trim().isNotEmpty ? sale.debtorName! : ' '
      ];

      final List<List<dynamic>> detallesRows = sale.details.map((d) => [
        sale.id,
        d.productId,
        d.productName,
        d.quantity,
        d.unitPriceUSD,
        d.subtotalUSD
      ]).toList();

      await _sendSaleToNetwork(sale, ventaRow, detallesRows);
    } catch (e) {
      throw Exception('Error al procesar la venta: $e');
    }
  }

  Future<void> _deductStock(List<SaleDetail> details) async {
    try {
      final products = await productRepository.getProducts();
      for (final detail in details) {
        final idx = products.indexWhere((p) => p.id == detail.productId);
        if (idx >= 0) {
          final currentStock = products[idx].stockQuantity;
          final newStock = (currentStock - detail.quantity).clamp(0, 999999);
          await productRepository.updateStock(detail.productId, newStock);
        }
      }
    } catch (e) {
      debugPrint('[SalesRepo] Error silencioso al descontar stock: $e');
    }
  }

  Future<void> _sendSaleToNetwork(Sale sale, List<dynamic> ventaRow, List<List<dynamic>> detallesRows) async {
    try {
      await _deductStock(sale.details);
    } catch (stockError) {
      debugPrint('[SalesRepo] Error al actualizar stock local: $stockError');
    }

    try {
      if (kIsWeb) {
        final ventaData = {
          'id_venta': sale.id, 'fecha': sale.date.toIso8601String(), 'total_usd': sale.totalUSD,
          'total_ves': sale.totalVES, 'tasa_cambio': sale.exchangeRate,
          'metodos_pago': sale.payments.map((p) => p.toJson()).toList(), 'pdf_url': ' ',
          'detalles': sale.debtorName != null && sale.debtorName!.trim().isNotEmpty ? sale.debtorName! : ' '
        };
        final detallesData = sale.details.map((d) => {
          'id_producto': d.productId, 'nombre_producto': d.productName,
          'cantidad': d.quantity, 'precio_unitario_usd': d.unitPriceUSD, 'subtotal_usd': d.subtotalUSD
        }).toList();
        
        await dio.post('$baseUrl/ventas', data: {'venta': ventaData, 'detalles': detallesData}).timeout(const Duration(seconds: 10)); 
      } else {
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: [ventaRow]), AppConstants.spreadSheetId, 'Ventas!A:H', valueInputOption: 'USER_ENTERED',
        ).timeout(const Duration(seconds: 10)); 
        
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: detallesRows), AppConstants.spreadSheetId, 'DetalleVentas!A:F', valueInputOption: 'USER_ENTERED',
        ).timeout(const Duration(seconds: 10)); 
      }
    } catch (networkError) {
      debugPrint('[SalesRepo] Modo Offline activado: Guardando venta localmente');
      await localStorageService.addPendingSale(_saleToJson(sale));
    }
  }

  Map<String, dynamic> _saleToJson(Sale sale) {
    return {
      'id_venta': sale.id, 'fecha': sale.date.toIso8601String(), 'total_usd': sale.totalUSD, 'total_ves': sale.totalVES,
      'tasa_cambio': sale.exchangeRate, 'metodos_pago': sale.payments.map((p) => p.toJson()).toList(), 'pdf_url': '',
      'detalles_nombre': sale.debtorName ?? '',
      'items': sale.details.map((d) => {'id_producto': d.productId, 'nombre_producto': d.productName, 'cantidad': d.quantity, 'precio_unitario_usd': d.unitPriceUSD, 'subtotal_usd': d.subtotalUSD}).toList(),
    };
  }

  Sale _mapJsonToSale(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? []).map((i) => SaleDetail(productId: i['id_producto'].toString(), productName: i['nombre_producto'].toString(), quantity: int.tryParse(i['cantidad'].toString()) ?? 0, unitPriceUSD: double.tryParse(i['precio_unitario_usd'].toString()) ?? 0.0)).toList();
    final payments = (json['metodos_pago'] as List? ?? []).map((p) => Payment(method: p['method']?.toString() ?? 'Desconocido', amount: (p['amount'] as num).toDouble())).toList();
    final sale = Sale(id: json['id_venta']?.toString() ?? '', date: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(), exchangeRate: double.tryParse(json['tasa_cambio'].toString()) ?? 1.0, details: items, payments: payments, debtorName: json['detalles_nombre']?.toString() == ' ' ? null : json['detalles_nombre']?.toString());
    sale.overrideTotals(double.tryParse(json['total_usd'].toString()) ?? 0.0, double.tryParse(json['total_ves'].toString()) ?? 0.0);
    return sale;
  }

  Future<void> updateSaleStatus(String idVenta, List<Payment> payments, {bool isSyncing = false}) async {
    final paymentsJsonList = payments.map((p) => p.toJson()).toList();
    try {
      final key = 'ventas_cache';
      final sales = await localStorageService.getCache('sales_cache', key, defaultValue: []) as List;
      for (var row in sales) {
        if (row.isNotEmpty && row[0].toString() == idVenta) {
          if (row.length > 6) row[6] = jsonEncode(paymentsJsonList);
          break;
        }
      }
      await localStorageService.saveCache('sales_cache', key, sales);
    } catch (_) {}

    try {
      if (kIsWeb) {
        await dio.put('$baseUrl/ventas/update_status', data: {'id_venta': idVenta, 'metodos_pago': paymentsJsonList}).timeout(const Duration(seconds: 15));
      } else {
        final vResp = await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'Ventas!A:A').timeout(const Duration(seconds: 15));
        final vRows = vResp.values ?? [];
        int rowIndex = -1;
        for (int i = 0; i < vRows.length; i++) {
          if (vRows[i].isNotEmpty && vRows[i][0].toString() == idVenta) { rowIndex = i + 1; break; }
        }
        if (rowIndex != -1) {
          await googleApi.sheetsApi.spreadsheets.values.update(sheets.ValueRange(values: [[jsonEncode(paymentsJsonList)]]), AppConstants.spreadSheetId, 'Ventas!G$rowIndex', valueInputOption: 'USER_ENTERED').timeout(const Duration(seconds: 15));
        } else {
          await localStorageService.addPendingPaymentUpdate(idVenta, paymentsJsonList);
        }
      }
    } catch (e) {
      if (isSyncing) rethrow; 
      await localStorageService.addPendingPaymentUpdate(idVenta, paymentsJsonList);
    }
  }

  Future<void> updateSale(Sale oldSale, Sale newSale) async {
    try {
      await deleteSale(oldSale);
      await processSale(newSale); 
    } catch (e) {
      throw Exception('Error al actualizar la venta: $e');
    }
  }

  Future<void> deleteSale(Sale sale, {bool isSyncing = false}) async {
    for (final detail in sale.details) {
      try {
        final products = await productRepository.getProducts();
        final idx = products.indexWhere((p) => p.id == detail.productId);
        if (idx >= 0) {
          await productRepository.updateStock(detail.productId, products[idx].stockQuantity + detail.quantity);
        }
      } catch (e) {}
    }

    try {
      final key = 'ventas_cache';
      final salesCache = await localStorageService.getCache('sales_cache', key, defaultValue: []) as List;
      salesCache.removeWhere((row) => row.isNotEmpty && row[0].toString() == sale.id);
      await localStorageService.saveCache('sales_cache', key, salesCache);
    } catch (e) {}

    try {
      if (kIsWeb) {
        await dio.delete('$baseUrl/ventas/${sale.id}').timeout(const Duration(seconds: 15));
      } else {
        final meta = await googleApi.sheetsApi.spreadsheets.get(AppConstants.spreadSheetId).timeout(const Duration(seconds: 15));
        final sheetVentas = meta.sheets?.firstWhere((s) => s.properties?.title == 'Ventas');
        final sheetDetalles = meta.sheets?.firstWhere((s) => s.properties?.title == 'DetalleVentas');
        final vResp = await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'Ventas!A:A').timeout(const Duration(seconds: 15));
        final dResp = await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'DetalleVentas!A:A').timeout(const Duration(seconds: 15));
        final vRows = vResp.values ?? [];
        final dRows = dResp.values ?? [];
        List<sheets.Request> requests = [];
        
        for (int i = dRows.length - 1; i >= 0; i--) {
          if (dRows[i].isNotEmpty && dRows[i][0] == sale.id) requests.add(sheets.Request(deleteDimension: sheets.DeleteDimensionRequest(range: sheets.DimensionRange(sheetId: sheetDetalles?.properties?.sheetId, dimension: 'ROWS', startIndex: i, endIndex: i + 1))));
        }
        for (int i = vRows.length - 1; i >= 0; i--) {
          if (vRows[i].isNotEmpty && vRows[i][0] == sale.id) requests.add(sheets.Request(deleteDimension: sheets.DeleteDimensionRequest(range: sheets.DimensionRange(sheetId: sheetVentas?.properties?.sheetId, dimension: 'ROWS', startIndex: i, endIndex: i + 1))));
        }
        if (requests.isNotEmpty) {
          await googleApi.sheetsApi.spreadsheets.batchUpdate(sheets.BatchUpdateSpreadsheetRequest(requests: requests), AppConstants.spreadSheetId).timeout(const Duration(seconds: 15));
        }
      }
    } catch (e) {
      if (isSyncing) rethrow; 
      await localStorageService.addPendingInventoryUpdate({'type': 'delete_sale', 'saleId': sale.id, 'timestamp': DateTime.now().toIso8601String()});
    }
  }

  Future<List<Sale>> getSalesHistory({int days = 30}) async {
    List<Sale> networkSales = [];
    try {
      List<dynamic> ventasRows = [];
      List<dynamic> detallesRows = [];

      try {
        if (kIsWeb) {
          ventasRows = (await dio.get('$baseUrl/ventas', queryParameters: {'days': days}).timeout(const Duration(seconds: 5))).data ?? [];
          detallesRows = (await dio.get('$baseUrl/detalle_ventas').timeout(const Duration(seconds: 5))).data ?? [];
        } else {
          if (!googleApi.isInitialized) await googleApi.init();
          ventasRows = (await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'Ventas!A2:H').timeout(const Duration(seconds: 5))).values ?? [];
          detallesRows = (await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'DetalleVentas!A2:F').timeout(const Duration(seconds: 5))).values ?? [];
          if (days > 0) {
            final cutoffDate = DateTime.now().subtract(Duration(days: days));
            ventasRows = ventasRows.where((row) {
              if (row.length < 2) return false;
              try { final date = DateTime.parse(row[1].toString()); return date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate); } catch (_) { return true; }
            }).toList();
          }
        }
        if (ventasRows.isNotEmpty) {
          await localStorageService.saveCache('sales_cache', 'ventas_cache', ventasRows);
          await localStorageService.saveCache('sales_cache', 'detalles_cache', detallesRows);
        }
      } catch (networkError) {
        ventasRows = await localStorageService.getCache('sales_cache', 'ventas_cache', defaultValue: []);
        detallesRows = await localStorageService.getCache('sales_cache', 'detalles_cache', defaultValue: []);
      }

      final Map<String, List<SaleDetail>> detailsMap = {};
      for (var row in detallesRows) {
        if (row.length >= 6) {
          detailsMap.putIfAbsent(row[0].toString(), () => []).add(SaleDetail(productId: row[1].toString(), productName: row[2].toString(), quantity: int.tryParse(row[3].toString()) ?? 0, unitPriceUSD: double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 0.0));
        }
      }

      networkSales = ventasRows.where((row) => row.length >= 5).map((row) {
        final totalUSD = double.tryParse(row[2].toString().replaceAll(',', '.')) ?? 0.0;
        List<Payment> parsedPayments = [];
        String? debtorName;
        int pIndex = -1;
        for (int i = 5; i < row.length; i++) { if (row[i].toString().trim().startsWith('[') && row[i].toString().trim().endsWith(']')) { pIndex = i; break; } }
        
        if (pIndex != -1) {
           try { parsedPayments = (jsonDecode(row[pIndex].toString()) as List).map((p) => Payment(method: p['method']?.toString() ?? 'Desconocido', amount: (p['amount'] as num).toDouble())).toList(); } catch(e) { parsedPayments = [Payment(method: 'Efectivo', amount: totalUSD)]; }
           if (row.length > pIndex + 1) debtorName = row[pIndex + 1].toString();
        } else {
           if (row.length >= 7 && row[6].toString().isNotEmpty && !row[6].toString().startsWith('http')) { parsedPayments = [Payment(method: row[6].toString(), amount: totalUSD)]; } else { parsedPayments = [Payment(method: 'Efectivo', amount: totalUSD)]; }
           if (row.length >= 8) debtorName = row[7].toString();
        }

        final sale = Sale(id: row[0].toString(), date: DateTime.tryParse(row[1].toString()) ?? DateTime.now(), exchangeRate: double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 1.0, details: detailsMap[row[0].toString()] ?? [], payments: parsedPayments, debtorName: debtorName);
        sale.overrideTotals(totalUSD, double.tryParse(row[3].toString().replaceAll(',', '.')) ?? 0.0);
        return sale;
      }).toList();
    } catch (e) {}

    List<Sale> pendingSales = [];
    try { pendingSales = (await localStorageService.getPendingSales()).map((j) => _mapJsonToSale(j)).toList(); } catch (e) {}

    final allSales = [...pendingSales, ...networkSales];

    try {
      for (final update in await localStorageService.getPendingPaymentUpdates()) {
        final saleIndex = allSales.indexWhere((s) => s.id == update['id_venta'].toString());
        if (saleIndex != -1) {
          final mappedPayments = (update['metodos_pago'] as List).map((p) => Payment(method: p['method']?.toString() ?? 'Desconocido', amount: (p['amount'] as num).toDouble())).toList();
          final old = allSales[saleIndex];
          allSales[saleIndex] = Sale(id: old.id, date: old.date, exchangeRate: old.exchangeRate, details: old.details, payments: mappedPayments, debtorName: old.debtorName)..overrideTotals(old.totalUSD, old.totalVES);
        }
      }
    } catch (e) {}

    allSales.sort((a, b) => b.date.compareTo(a.date));
    return allSales;
  }

  Future<void> resyncSale(Map<String, dynamic> saleJson) async {
    if (kIsWeb) {
      await dio.post('$baseUrl/ventas', data: {
        'venta': { 'id_venta': saleJson['id_venta'], 'fecha': saleJson['fecha'], 'total_usd': saleJson['total_usd'], 'total_ves': saleJson['total_ves'], 'tasa_cambio': saleJson['tasa_cambio'], 'metodos_pago': saleJson['metodos_pago'], 'pdf_url': saleJson['pdf_url'], 'detalles': saleJson['detalles_nombre'] },
        'detalles': (saleJson['items'] as List).map((d) => { 'id_producto': d['id_producto'], 'nombre_producto': d['nombre_producto'], 'cantidad': d['cantidad'], 'precio_unitario_usd': d['precio_unitario_usd'], 'subtotal_usd': d['subtotal_usd'] }).toList(),
      });
    } else {
      await googleApi.sheetsApi.spreadsheets.values.append(sheets.ValueRange(values: [[saleJson['id_venta'], saleJson['fecha'], saleJson['total_usd'], saleJson['total_ves'], saleJson['tasa_cambio'], saleJson['pdf_url'], jsonEncode(saleJson['metodos_pago']), saleJson['detalles_nombre']]]), AppConstants.spreadSheetId, 'Ventas!A:H', valueInputOption: 'USER_ENTERED');
      final detalleRows = (saleJson['items'] as List).map<List<dynamic>>((d) => [saleJson['id_venta'], d['id_producto'], d['nombre_producto'], d['cantidad'], d['precio_unitario_usd'], d['subtotal_usd']]).toList();
      if (detalleRows.isNotEmpty) await googleApi.sheetsApi.spreadsheets.values.append(sheets.ValueRange(values: detalleRows), AppConstants.spreadSheetId, 'DetalleVentas!A:F', valueInputOption: 'USER_ENTERED');
    }
  }

  Future<void> resyncPaymentUpdate(Map<String, dynamic> updateJson) async {
    await updateSaleStatus(updateJson['id_venta'], (updateJson['metodos_pago'] as List).map((p) => Payment(method: p['method']?.toString() ?? 'Desconocido', amount: (p['amount'] as num).toDouble())).toList(), isSyncing: true);
  }
}
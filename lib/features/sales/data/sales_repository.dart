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
      // LLAMADA INMEDIATA A RED/OFFLINE PARA PROTEGER LA VENTA
      // Se eliminó cualquier bucle previo de descuento de stock para dar prioridad a la persistencia.
      
      final ventaRow = [
        sale.id,
        sale.date.toIso8601String(),
        sale.totalUSD,
        sale.totalVES,
        sale.exchangeRate,
        ' ', // pdf_url placeholder
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

  Future<void> _sendSaleToNetwork(
    Sale sale,
    List<dynamic> ventaRow,
    List<List<dynamic>> detallesRows,
  ) async {
    try {
      // 1. Persistencia de la Venta (Modo Híbrido)
      if (kIsWeb) {
        final ventaData = {
          'id_venta': sale.id,
          'fecha': sale.date.toIso8601String(),
          'total_usd': sale.totalUSD,
          'total_ves': sale.totalVES,
          'tasa_cambio': sale.exchangeRate,
          'metodos_pago': sale.payments.map((p) => p.toJson()).toList(),
          'pdf_url': ' ',
          'detalles': sale.debtorName != null && sale.debtorName!.trim().isNotEmpty ? sale.debtorName! : ' '
        };
        final detallesData = sale.details.map((d) => {
          'id_producto': d.productId,
          'nombre_producto': d.productName,
          'cantidad': d.quantity,
          'precio_unitario_usd': d.unitPriceUSD,
          'subtotal_usd': d.subtotalUSD
        }).toList();
        
        await dio.post('$baseUrl/ventas', data: {
          'venta': ventaData,
          'detalles': detallesData,
        });
      } else {
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: [ventaRow]),
          AppConstants.spreadSheetId,
          'Ventas!A:H',
          valueInputOption: 'USER_ENTERED',
        );
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: detallesRows),
          AppConstants.spreadSheetId,
          'DetalleVentas!A:F',
          valueInputOption: 'USER_ENTERED',
        );
      }

      // 2. Si la persistencia fue exitosa, descontar stock en bloque silencioso
      try {
        await _deductStock(sale.details);
      } catch (stockError) {
        debugPrint('[SalesRepo] Error al actualizar stock (pero venta guardada): $stockError');
      }

    } catch (networkError) {
      // SALVAVIDAS: Fallo de red → guardar en cola offline inmediata
      debugPrint('[SalesRepo] Modo Offline activado: Guardando venta localmente');
      await localStorageService.addPendingSale(_saleToJson(sale));
    }
  }

  Map<String, dynamic> _saleToJson(Sale sale) {
    return {
      'id_venta': sale.id,
      'fecha': sale.date.toIso8601String(),
      'total_usd': sale.totalUSD,
      'total_ves': sale.totalVES,
      'tasa_cambio': sale.exchangeRate,
      'metodos_pago': sale.payments.map((p) => p.toJson()).toList(),
      'pdf_url': '',
      'detalles_nombre': sale.debtorName ?? '',
      'items': sale.details.map((d) => {
        'id_producto': d.productId,
        'nombre_producto': d.productName,
        'cantidad': d.quantity,
        'precio_unitario_usd': d.unitPriceUSD,
        'subtotal_usd': d.subtotalUSD,
      }).toList(),
    };
  }

  Sale _mapJsonToSale(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? []).map((i) => SaleDetail(
      productId: i['id_producto'].toString(),
      productName: i['nombre_producto'].toString(),
      quantity: int.tryParse(i['cantidad'].toString()) ?? 0,
      unitPriceUSD: double.tryParse(i['precio_unitario_usd'].toString()) ?? 0.0,
    )).toList();

    final payments = (json['metodos_pago'] as List? ?? []).map((p) => Payment(
      method: p['method']?.toString() ?? 'Desconocido',
      amount: (p['amount'] as num).toDouble(),
    )).toList();

    final sale = Sale(
      id: json['id_venta']?.toString() ?? '',
      date: DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      exchangeRate: double.tryParse(json['tasa_cambio'].toString()) ?? 1.0,
      details: items,
      payments: payments,
      debtorName: json['detalles_nombre']?.toString() == ' ' ? null : json['detalles_nombre']?.toString(),
    );
    
    sale.overrideTotals(
      double.tryParse(json['total_usd'].toString()) ?? 0.0,
      double.tryParse(json['total_ves'].toString()) ?? 0.0,
    );
    return sale;
  }

  Future<void> resyncSale(Map<String, dynamic> saleJson) async {
    if (kIsWeb) {
      final detallesData = (saleJson['items'] as List).map((d) => {
        'id_producto': d['id_producto'],
        'nombre_producto': d['nombre_producto'],
        'cantidad': d['cantidad'],
        'precio_unitario_usd': d['precio_unitario_usd'],
        'subtotal_usd': d['subtotal_usd'],
      }).toList();
      await dio.post('$baseUrl/ventas', data: {
        'venta': {
          'id_venta': saleJson['id_venta'],
          'fecha': saleJson['fecha'],
          'total_usd': saleJson['total_usd'],
          'total_ves': saleJson['total_ves'],
          'tasa_cambio': saleJson['tasa_cambio'],
          'metodos_pago': saleJson['metodos_pago'],
          'pdf_url': saleJson['pdf_url'],
          'detalles': saleJson['detalles_nombre'],
        },
        'detalles': detallesData,
      });
    } else {
      final row = [
        saleJson['id_venta'],
        saleJson['fecha'],
        saleJson['total_usd'],
        saleJson['total_ves'],
        saleJson['tasa_cambio'],
        saleJson['pdf_url'],
        jsonEncode(saleJson['metodos_pago']),
        saleJson['detalles_nombre'],
      ];
      await googleApi.sheetsApi.spreadsheets.values.append(
        sheets.ValueRange(values: [row]),
        AppConstants.spreadSheetId,
        'Ventas!A:H',
        valueInputOption: 'USER_ENTERED',
      );
      final items = saleJson['items'] as List;
      final detalleRows = items.map<List<dynamic>>((d) => [
        saleJson['id_venta'],
        d['id_producto'],
        d['nombre_producto'],
        d['cantidad'],
        d['precio_unitario_usd'],
        d['subtotal_usd'],
      ]).toList();
      if (detalleRows.isNotEmpty) {
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: detalleRows),
          AppConstants.spreadSheetId,
          'DetalleVentas!A:F',
          valueInputOption: 'USER_ENTERED',
        );
      }
    }

    try {
      final items = saleJson['items'] as List;
      for (final item in items) {
        final productId = item['id_producto'].toString();
        final quantity = int.tryParse(item['cantidad'].toString()) ?? 0;
        final products = await productRepository.getProducts();
        final idx = products.indexWhere((p) => p.id == productId);
        if (idx >= 0) {
          final currentStock = products[idx].stockQuantity;
          final newStock = (currentStock - quantity).clamp(0, 999999);
          await productRepository.updateStock(productId, newStock);
        }
      }
    } catch (e) {
      debugPrint('Error al actualizar stock en resync: $e');
    }
  }

  Future<List<Sale>> getSalesHistory({int days = 30}) async {
    List<Sale> networkSales = [];
    
    // 1. Intentar llamadas de red
    try {
      List<dynamic> ventasRows = [];
      List<dynamic> detallesRows = [];

      if (kIsWeb) {
        final ventasResp = await dio.get('$baseUrl/ventas', queryParameters: {'days': days});
        final detallesResp = await dio.get('$baseUrl/detalle_ventas');
        ventasRows = ventasResp.data ?? [];
        detallesRows = detallesResp.data ?? [];
      } else {
        final vResp = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Ventas!A2:H',
        );
        final dResp = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'DetalleVentas!A2:F',
        );
        ventasRows = vResp.values ?? [];
        detallesRows = dResp.values ?? [];

        if (days > 0) {
          final cutoffDate = DateTime.now().subtract(Duration(days: days));
          ventasRows = ventasRows.where((row) {
            if (row.length < 2) return false;
            try {
               final date = DateTime.parse(row[1].toString());
               return date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate);
            } catch (_) {
               return true;
            }
          }).toList();
        }
      }

      final Map<String, List<SaleDetail>> detailsMap = {};
      for (var row in detallesRows) {
        if (row.length >= 6) {
          final saleId = row[0].toString();
          detailsMap.putIfAbsent(saleId, () => []).add(SaleDetail(
            productId: row[1].toString(),
            productName: row[2].toString(),
            quantity: int.tryParse(row[3].toString()) ?? 0,
            unitPriceUSD: double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 0.0,
          ));
        }
      }

      networkSales = ventasRows.where((row) => row.length >= 5).map((row) {
        final saleId = row[0].toString();
        final dateStr = row[1].toString();
        final totalUSD = double.tryParse(row[2].toString().replaceAll(',', '.')) ?? 0.0;
        final totalVES = double.tryParse(row[3].toString().replaceAll(',', '.')) ?? 0.0;
        final exchangeRate = double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 1.0;
        
        List<Payment> parsedPayments = [];
        String? debtorName;

        int pIndex = -1;
        for (int i = 5; i < row.length; i++) {
           String val = row[i].toString().trim();
           if (val.startsWith('[') && val.endsWith(']')) {
              pIndex = i;
              break;
           }
        }

        if (pIndex != -1) {
           try {
             final pmList = jsonDecode(row[pIndex].toString()) as List;
             parsedPayments = pmList.map((p) => Payment(method: p['method']?.toString() ?? 'Desconocido', amount: (p['amount'] as num).toDouble())).toList();
           } catch(e) {
             parsedPayments = [Payment(method: 'Efectivo', amount: totalUSD)];
           }
           if (row.length > pIndex + 1) debtorName = row[pIndex + 1].toString();
        } else {
           if (row.length >= 7 && row[6].toString().isNotEmpty && !row[6].toString().startsWith('http')) {
              parsedPayments = [Payment(method: row[6].toString(), amount: totalUSD)];
           } else {
              parsedPayments = [Payment(method: 'Efectivo', amount: totalUSD)];
           }
           if (row.length >= 8) debtorName = row[7].toString();
        }

        final sale = Sale(
          id: saleId,
          date: DateTime.tryParse(dateStr) ?? DateTime.now(),
          exchangeRate: exchangeRate,
          details: detailsMap[saleId] ?? [],
          payments: parsedPayments,
          debtorName: debtorName,
        );
        sale.overrideTotals(totalUSD, totalVES);
        return sale;
      }).toList();
    } catch (e) {
      debugPrint('[SalesRepo] Error cargando historial remoto: $e');
    }

    // 2. Concatenar con ventas offline pendientes
    List<Sale> pendingSales = [];
    try {
      final localJsons = await localStorageService.getPendingSales();
      pendingSales = localJsons.map((j) => _mapJsonToSale(j)).toList();
    } catch (e) {
      debugPrint('[SalesRepo] Error cargando ventas locales: $e');
    }

    final allSales = [...pendingSales, ...networkSales];
    allSales.sort((a, b) => b.date.compareTo(a.date));
    return allSales;
  }

  Future<void> updateSale(Sale oldSale, Sale newSale) async {
    try {
      await deleteSale(oldSale);
      await processSale(newSale); 
    } catch (e) {
      throw Exception('Error al actualizar la venta: $e');
    }
  }

  Future<void> updateSaleStatus(String idVenta, List<Payment> payments) async {
    try {
      if (kIsWeb) {
        await dio.put('$baseUrl/ventas/update_status', data: {
          'id_venta': idVenta,
          'metodos_pago': payments.map((p) => p.toJson()).toList(),
        });
      } else {
        final vResp = await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'Ventas!A:A');
        final vRows = vResp.values ?? [];
        int rowIndex = -1;
        for (int i = 0; i < vRows.length; i++) {
          if (vRows[i].isNotEmpty && vRows[i][0].toString() == idVenta) {
            rowIndex = i + 1;
            break;
          }
        }
        if (rowIndex != -1) {
          final paymentsJson = jsonEncode(payments.map((p) => p.toJson()).toList());
          await googleApi.sheetsApi.spreadsheets.values.update(
            sheets.ValueRange(values: [[paymentsJson]]),
            AppConstants.spreadSheetId,
            'Ventas!G$rowIndex',
            valueInputOption: 'USER_ENTERED',
          );
        }
      }
    } catch (e) {
      throw Exception('Error al actualizar el estado de la venta: $e');
    }
  }

  Future<void> deleteSale(Sale sale) async {
    try {
      for (final detail in sale.details) {
        final products = await productRepository.getProducts();
        final idx = products.indexWhere((p) => p.id == detail.productId);
        if (idx >= 0) {
          final currentStock = products[idx].stockQuantity;
          final newStock = currentStock + detail.quantity; 
          await productRepository.updateStock(detail.productId, newStock);
        }
      }

      if (kIsWeb) {
        await dio.delete('$baseUrl/ventas/${sale.id}');
      } else {
        final meta = await googleApi.sheetsApi.spreadsheets.get(AppConstants.spreadSheetId);
        final sheetVentas = meta.sheets?.firstWhere((s) => s.properties?.title == 'Ventas');
        final sheetDetalles = meta.sheets?.firstWhere((s) => s.properties?.title == 'DetalleVentas');
        final vResp = await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'Ventas!A:A');
        final dResp = await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'DetalleVentas!A:A');
        final vRows = vResp.values ?? [];
        final dRows = dResp.values ?? [];
        List<sheets.Request> requests = [];
        
        for (int i = dRows.length - 1; i >= 0; i--) {
          if (dRows[i].isNotEmpty && dRows[i][0] == sale.id) {
            requests.add(sheets.Request(deleteDimension: sheets.DeleteDimensionRequest(
              range: sheets.DimensionRange(
                sheetId: sheetDetalles?.properties?.sheetId,
                dimension: 'ROWS',
                startIndex: i,
                endIndex: i + 1,
              )
            )));
          }
        }
        for (int i = vRows.length - 1; i >= 0; i--) {
          if (vRows[i].isNotEmpty && vRows[i][0] == sale.id) {
            requests.add(sheets.Request(deleteDimension: sheets.DeleteDimensionRequest(
              range: sheets.DimensionRange(
                sheetId: sheetVentas?.properties?.sheetId,
                dimension: 'ROWS',
                startIndex: i,
                endIndex: i + 1,
              )
            )));
          }
        }
        if (requests.isNotEmpty) {
          await googleApi.sheetsApi.spreadsheets.batchUpdate(
            sheets.BatchUpdateSpreadsheetRequest(requests: requests),
            AppConstants.spreadSheetId,
          );
        }
      }
    } catch (e) {
      throw Exception('Error al eliminar la venta: $e');
    }
  }
}
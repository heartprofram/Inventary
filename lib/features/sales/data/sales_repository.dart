import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../../core/services/google_api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/sale.dart';
import '../domain/entities/payment.dart';
import '../../inventory/data/product_repository.dart';

class SalesRepository {
  final Dio dio;
  final GoogleApiService googleApi;
  final ProductRepository productRepository;
  final String baseUrl = 'http://localhost:8081/api';

  SalesRepository({
    required this.dio, 
    required this.googleApi,
    required this.productRepository,
  });

  Future<void> processSale(Sale sale) async {
    try {
      // 1. Descontar inventario (el repositorio de productos ya maneja kIsWeb internamente)
      for (final detail in sale.details) {
        final products = await productRepository.getProducts();
        final idx = products.indexWhere((p) => p.id == detail.productId);
        if (idx >= 0) {
          final currentStock = products[idx].stockQuantity;
          final newStock = (currentStock - detail.quantity).clamp(0, 999999);
          await productRepository.updateStock(detail.productId, newStock);
        }
      }

      // 2. Preparar los datos
      final ventaRow = [
        sale.id,
        sale.date.toIso8601String(),
        sale.totalUSD,
        sale.totalVES,
        sale.exchangeRate,
        jsonEncode(sale.payments.map((p) => p.toJson()).toList()),
        '', // pdf_url
        sale.debtorName ?? ''
      ];

      final List<List<dynamic>> detallesRows = sale.details.map((d) => [
        sale.id,
        d.productId,
        d.productName,
        d.quantity,
        d.unitPriceUSD,
        d.subtotalUSD
      ]).toList();

      // 3. Enviar a Google Sheets
      if (kIsWeb) {
        final ventaData = {
          'id_venta': sale.id,
          'fecha': sale.date.toIso8601String(),
          'total_usd': sale.totalUSD,
          'total_ves': sale.totalVES,
          'tasa_cambio': sale.exchangeRate,
          'metodos_pago': sale.payments.map((p) => p.toJson()).toList(),
          'pdf_url': '',
          'detalles': sale.debtorName ?? ''
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
        // Guardar cabecera de la venta
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: [ventaRow]),
          AppConstants.spreadSheetId,
          'Ventas!A:H',
          valueInputOption: 'USER_ENTERED',
        );

        // Guardar detalles de la venta
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: detallesRows),
          AppConstants.spreadSheetId,
          'DetalleVentas!A:F',
          valueInputOption: 'USER_ENTERED',
        );
      }
    } catch (e) {
      throw Exception('Error al procesar la venta: $e');
    }
  }

  Future<List<Sale>> getSalesHistory() async {
    try {
      List<dynamic> ventasRows;
      List<dynamic> detallesRows;

      if (kIsWeb) {
        final ventasResp = await dio.get('$baseUrl/ventas');
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
      }

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
          detailsMap.putIfAbsent(saleId, () => []).add(detail);
        }
      }

      final List<Sale> sales = ventasRows.where((row) => row.length >= 5).map((row) {
        final saleId = row[0].toString();
        final dateStr = row[1].toString();
        final totalUSD = double.tryParse(row[2].toString().replaceAll(',', '.')) ?? 0.0;
        final totalVES = double.tryParse(row[3].toString().replaceAll(',', '.')) ?? 0.0;
        final exchangeRate = double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 1.0;
        
        List<Payment> parsedPayments = [];
        if (row.length >= 6 && row[5].toString().isNotEmpty) {
           try {
             final List<dynamic> pmList = jsonDecode(row[5].toString());
             parsedPayments = pmList.map((p) => Payment(method: p['method'], amount: (p['amount'] as num).toDouble())).toList();
           } catch(e) {
             parsedPayments = [Payment(method: row[5].toString(), amount: totalUSD)];
           }
        } else {
           parsedPayments = [Payment(method: 'Efectivo', amount: totalUSD)];
        }

        final debtorName = row.length >= 8 ? row[7].toString() : null;
        final details = detailsMap[saleId] ?? [];
        
        return Sale(
          id: saleId,
          date: DateTime.tryParse(dateStr) ?? DateTime.now(),
          exchangeRate: exchangeRate,
          details: details,
          payments: parsedPayments,
          debtorName: debtorName,
        )..overrideTotals(totalUSD, totalVES);
      }).toList();

      sales.sort((a, b) => b.date.compareTo(a.date));
      return sales;
    } catch (e) {
      throw Exception('Error al obtener el historial de ventas: $e');
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

  Future<void> updateSaleStatus(String idVenta, List<Payment> payments) async {
    try {
      if (kIsWeb) {
        await dio.put('$baseUrl/ventas/update_status', data: {
          'id_venta': idVenta,
          'metodos_pago': payments.map((p) => p.toJson()).toList(),
        });
      } else {
        // Buscar fila por ID en Ventas (Col A) y actualizar Col F (Métodos de Pago)
        final vResp = await googleApi.sheetsApi.spreadsheets.values.get(AppConstants.spreadSheetId, 'Ventas!A:A');
        final vRows = vResp.values ?? [];
        
        int rowIndex = -1;
        for (int i = 0; i < vRows.length; i++) {
          if (vRows[i].isNotEmpty && vRows[i][0].toString() == idVenta) {
            rowIndex = i + 1; // 1-indexed para Sheets
            break;
          }
        }

        if (rowIndex != -1) {
          final paymentsJson = jsonEncode(payments.map((p) => p.toJson()).toList());
          await googleApi.sheetsApi.spreadsheets.values.update(
            sheets.ValueRange(values: [[paymentsJson]]),
            AppConstants.spreadSheetId,
            'Ventas!F$rowIndex',
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
      // 1. Devolver el stock (Asegurando que sea antes de borrar)
      for (final detail in sale.details) {
        final products = await productRepository.getProducts();
        final idx = products.indexWhere((p) => p.id == detail.productId);
        if (idx >= 0) {
          final currentStock = products[idx].stockQuantity;
          final newStock = currentStock + detail.quantity; 
          await productRepository.updateStock(detail.productId, newStock);
        }
      }

      // 2. Borrar la venta
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
        
        // Buscar índices en DetalleVentas (de abajo hacia arriba para no alterar índices previos)
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
        
        // Buscar índice en Ventas
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
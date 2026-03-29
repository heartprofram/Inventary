import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import '../../../core/services/google_api_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/entities/payment.dart';

class ReportsRepository {
  final Dio dio;
  final GoogleApiService googleApi;
  final LocalStorageService localStorageService;
  final String baseUrl = 'http://localhost:8081/api';

  ReportsRepository({
    required this.dio,
    required this.googleApi,
    required this.localStorageService,
  });

  // SOLUCIÓN: Ahora recibe un DateTime por parámetro
  Future<List<Sale>> getDailySales(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final String cacheKey = 'daily_sales_$dateStr';

    List<dynamic> rows = [];

    try {
      // 1. INTENTO DE RED (Network-First)
      if (kIsWeb) {
        final response = await dio.get('$baseUrl/ventas').timeout(const Duration(seconds: 5));
        rows = response.data ?? [];
      } else {
        final response = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Ventas!A2:H',
        ).timeout(const Duration(seconds: 10));
        rows = response.values ?? [];
      }
      
      // 2. ACTUALIZAR CACHÉ TRAS ÉXITO
      if (rows.isNotEmpty) {
        await localStorageService.saveCache('sales_cache', cacheKey, rows);
      }
    } catch (e) {
      debugPrint('[ReportsRepo] Fallo de red, rescatando caché financiero: $e');
      
      // 3. FALLBACK A CACHÉ (SOLUCIÓN CACHÉ FINANCIERO)
      rows = await localStorageService.getCache('sales_cache', cacheKey, defaultValue: []) as List<dynamic>;
    }

    // 4. MAPEO DE DATOS
    try {
      final List<Sale> sales = [];
      for (var row in rows) {
        if (row.length >= 5 && row[1].toString().startsWith(dateStr)) {
          final totalUSD = double.tryParse(row[2].toString().replaceAll(',', '.')) ?? 0.0;
          
          // Mapeo robusto de pagos
          List<Payment> payments = [];
          if (row.length >= 7 && row[6].toString().isNotEmpty) {
             try {
               final dynamic rawPm = row[6];
               final List<dynamic> pmList = rawPm is String ? jsonDecode(rawPm) : rawPm;
               payments = pmList.map((p) => Payment(
                 method: p['method']?.toString() ?? 'Efectivo', 
                 amount: (p['amount'] as num?)?.toDouble() ?? 0.0
               )).toList();
             } catch(_) {
               payments = [Payment(method: 'Efectivo', amount: totalUSD)];
             }
          } else {
             payments = [Payment(method: 'Efectivo', amount: totalUSD)];
          }

          final s = Sale(
            id: row[0].toString(),
            date: DateTime.tryParse(row[1].toString()) ?? date,
            exchangeRate: double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 0.0,
            details: [],
            payments: payments,
          )..overrideTotals(totalUSD, double.tryParse(row[3].toString().replaceAll(',', '.')) ?? 0.0);
          
          sales.add(s);
        }
      }
      return sales;
    } catch (e) {
      debugPrint('[ReportsRepo] Error procesando datos: $e');
      return []; // SOLUCIÓN: Nunca lanzar excepción que rompa la UI
    }
  }
}

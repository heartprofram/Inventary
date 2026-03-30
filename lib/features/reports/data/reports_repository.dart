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


  Future<List<Sale>> getDailySales(DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final String cacheKey = 'daily_sales_$dateStr';

    List<dynamic> rows = [];
    List<Sale> networkSales = [];

    try {
      if (kIsWeb) {
        final response = await dio.get('$baseUrl/ventas').timeout(const Duration(seconds: 5));
        rows = response.data ?? [];
      } else {
        // SOLUCIÓN 1: Iniciar sesión en Google API antes de consultar
        if (!googleApi.isInitialized) await googleApi.init();
        
        final response = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Ventas!A2:H',
        ).timeout(const Duration(seconds: 5));
        rows = response.values ?? [];
      }
      
      if (rows.isNotEmpty) {
        await localStorageService.saveCache('sales_cache', cacheKey, rows);
      }
    } catch (e) {
      debugPrint('[ReportsRepo] Fallo de red, rescatando caché financiero: $e');
      rows = await localStorageService.getCache('sales_cache', cacheKey, defaultValue: []) as List<dynamic>;
    }

    try {
      for (var row in rows) {
        if (row.length >= 5 && row[1].toString().startsWith(dateStr)) {
          final totalUSD = double.tryParse(row[2].toString().replaceAll(',', '.')) ?? 0.0;
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
          
          networkSales.add(s);
        }
      }
    } catch (e) {
      debugPrint('[ReportsRepo] Error procesando datos de red: $e');
    }

    // SOLUCIÓN 2: AÑADIR LAS VENTAS HECHAS OFFLINE AL CIERRE DE CAJA
    List<Sale> pendingSales = [];
    try {
      final pendingJsons = await localStorageService.getPendingSales();
      for (var json in pendingJsons) {
        final saleDate = DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now();
        // Solo mostrar en el cierre si la venta es de "Hoy"
        if (saleDate.year == date.year && saleDate.month == date.month && saleDate.day == date.day) {
          final payments = (json['metodos_pago'] as List? ?? []).map((p) => Payment(
            method: p['method']?.toString() ?? 'Desconocido',
            amount: (p['amount'] as num).toDouble(),
          )).toList();
          
          final totalUsd = double.tryParse(json['total_usd'].toString()) ?? 0.0;
          final totalVes = double.tryParse(json['total_ves'].toString()) ?? 0.0;

          final s = Sale(
            id: json['id_venta']?.toString() ?? '',
            date: saleDate,
            exchangeRate: double.tryParse(json['tasa_cambio'].toString()) ?? 1.0,
            details: [],
            payments: payments,
            debtorName: json['detalles_nombre']?.toString() == ' ' ? null : json['detalles_nombre']?.toString(),
          )..overrideTotals(totalUsd, totalVes);

          pendingSales.add(s);
        }
      }
    } catch (e) {
      debugPrint('[ReportsRepo] Error procesando ventas offline: $e');
    }

    final allSales = [...pendingSales, ...networkSales];

    // SOLUCIÓN 3: APLICAR LOS ABONOS (DEUDAS LIQUIDADAS) AL CIERRE DE CAJA
    try {
      final pendingPayments = await localStorageService.getPendingPaymentUpdates();
      for (final update in pendingPayments) {
        final saleId = update['id_venta'].toString();
        final saleIndex = allSales.indexWhere((s) => s.id == saleId);
        
        if (saleIndex != -1) {
          final rawPayments = update['metodos_pago'] as List;
          final mappedPayments = rawPayments.map((p) => Payment(
            method: p['method']?.toString() ?? 'Desconocido',
            amount: (p['amount'] as num).toDouble(),
          )).toList();
          
          final old = allSales[saleIndex];
          allSales[saleIndex] = Sale(
            id: old.id,
            date: old.date,
            exchangeRate: old.exchangeRate,
            details: old.details,
            payments: mappedPayments,
            debtorName: old.debtorName,
          )..overrideTotals(old.totalUSD, old.totalVES);
        }
      }
    } catch (e) {}

    return allSales;
  }
}

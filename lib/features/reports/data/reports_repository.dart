import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import '../../../core/services/google_api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/entities/payment.dart';

class ReportsRepository {
  final Dio dio;
  final GoogleApiService googleApi;
  final String baseUrl = 'http://localhost:8081/api';

  ReportsRepository({required this.dio, required this.googleApi});

  Future<List<Sale>> getDailySales() async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      List<dynamic> rows;
      
      if (kIsWeb) {
        final response = await dio.get('$baseUrl/ventas');
        rows = response.data ?? [];
      } else {
        final response = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Ventas!A2:H',
        );
        rows = response.values ?? [];
      }
      
      final List<Sale> dailySales = [];

      for (var row in rows) {
        if (row.length >= 5) {
          final dateStr = row[1].toString();
          
          // Solo tomar las ventas que coincidan con la fecha de hoy
          if (dateStr.startsWith(todayStr)) {
            final totalUSD = double.tryParse(row[2].toString().replaceAll(',', '.')) ?? 0.0;
            
            List<Payment> parsedPayments = [];
            if (row.length >= 7 && row[6].toString().isNotEmpty) {
               try {
                 final List<dynamic> pmList = jsonDecode(row[6].toString());
                 parsedPayments = pmList.map((p) => Payment(method: p['method'], amount: (p['amount'] as num).toDouble())).toList();
               } catch(e) {
                 parsedPayments = [Payment(method: row[6].toString(), amount: totalUSD)];
               }
            } else {
               parsedPayments = [Payment(method: 'Efectivo', amount: totalUSD)];
            }

            final sale = Sale(
              id: row[0].toString(),
              date: DateTime.parse(dateStr),
              exchangeRate: double.tryParse(row[4].toString().replaceAll(',', '.')) ?? 0.0,
              details: [], // El reporte diario no necesita el detalle completo de los productos
              payments: parsedPayments,
            )..overrideTotals(
                totalUSD,
                double.tryParse(row[3].toString().replaceAll(',', '.')) ?? 0.0,
              );
            dailySales.add(sale);
          }
        }
      }

      return dailySales;
    } catch (e) {
      throw Exception('Error al obtener las ventas del día: $e');
    }
  }
}
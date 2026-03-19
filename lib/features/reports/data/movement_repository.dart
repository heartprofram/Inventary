import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import '../../../core/services/google_api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/movement.dart';

class MovementRepository {
  final Dio dio;
  final GoogleApiService googleApi;
  final String baseUrl = 'http://localhost:8081/api';

  MovementRepository({required this.dio, required this.googleApi});

  Future<List<Movement>> getMovements() async {
    try {
      List<dynamic> rows;
      
      if (kIsWeb) {
        final response = await dio.get('$baseUrl/movimientos');
        rows = response.data ?? [];
      } else {
        final response = await googleApi.sheetsApi.spreadsheets.values.get(
          AppConstants.spreadSheetId,
          'Movimientos!A2:F',
        );
        rows = response.values ?? [];
      }
      
      return rows.where((row) => row.length >= 6).map((row) {
        return Movement(
          id: row[0].toString(),
          date: DateTime.parse(row[1].toString()),
          type: row[2].toString(),
          description: row[3].toString(),
          amountUSD: double.tryParse(row[4].toString()) ?? 0.0,
          amountVES: double.tryParse(row[5].toString()) ?? 0.0,
        );
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener movimientos: $e');
    }
  }

  Future<void> addMovement(Movement movement) async {
    try {
      final row = [
        movement.id,
        movement.date.toIso8601String(),
        movement.type,
        movement.description,
        movement.amountUSD,
        movement.amountVES,
      ];

      if (kIsWeb) {
        await dio.post('$baseUrl/movimientos', data: {'row': row});
      } else {
        await googleApi.sheetsApi.spreadsheets.values.append(
          sheets.ValueRange(values: [row]),
          AppConstants.spreadSheetId,
          'Movimientos!A:F',
          valueInputOption: 'USER_ENTERED',
        );
      }
    } catch (e) {
      throw Exception('Error al agregar movimiento: $e');
    }
  }
}
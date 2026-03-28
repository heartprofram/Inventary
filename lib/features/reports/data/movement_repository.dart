import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:dio/dio.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:hive/hive.dart';
import '../../../core/services/google_api_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/movement.dart';

class MovementRepository {
  final Dio dio;
  final GoogleApiService googleApi;
  final LocalStorageService localStorageService;
  final String baseUrl = 'http://localhost:8081/api';

  MovementRepository({
    required this.dio,
    required this.googleApi,
    required this.localStorageService,
  });

  Future<List<Movement>> getMovements({int days = 30}) async {
    try {
      List<dynamic> rows = [];
      
      try {
        if (kIsWeb) {
          // Modo Web: Uso de Dio contra Backend Python
          final response = await dio.get('$baseUrl/movimientos', queryParameters: {'days': days});
          rows = response.data ?? [];
        } else {
          // Modo Nativo: Uso directo de Google Sheets API
          final response = await googleApi.sheetsApi.spreadsheets.values.get(
            AppConstants.spreadSheetId,
            'Movimientos!A2:F',
          );
          rows = response.values ?? [];
          
          if (days > 0) {
            final cutoffDate = DateTime.now().subtract(Duration(days: days));
            rows = rows.where((row) {
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

        // GUARDADO EN CACHE SI RED TIENE ÉXITO
        if (rows.isNotEmpty) {
          final box = Hive.box('movements_cache');
          await box.put('mov_cache', rows);
        }
      } catch (networkError) {
        debugPrint('[MovementRepo] Error de red, cargando movimientos de cache local: $networkError');
        // RESCATE DE CACHE SI RED FALLA
        final box = Hive.box('movements_cache');
        rows = box.get('mov_cache', defaultValue: []);
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
    } catch (networkError) {
      debugPrint('[MovementRepo] Error de red, guardando en modo offline: $networkError');
      await localStorageService.addPendingMovement(movement.toMap());
    }
  }

  Future<void> resyncMovement(Map<String, dynamic> movementMap) async {
    final row = [
      movementMap['id'],
      movementMap['date'],
      movementMap['type'],
      movementMap['description'],
      movementMap['amountUSD'],
      movementMap['amountVES'],
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
  }
}
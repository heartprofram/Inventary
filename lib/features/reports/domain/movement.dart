import '../../../core/constants/app_constants.dart';
import '../../../core/services/google_api_service.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

class Movement {
  final String id;
  final DateTime date;
  final String type; // "Ingreso" o "Egreso"
  final String description;
  final double amountUSD;
  final double amountVES;

  Movement({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.amountUSD,
    required this.amountVES,
  });

  factory Movement.fromList(List<dynamic> row) {
    return Movement(
      id: row.isNotEmpty ? row[0].toString() : '',
      date: row.length > 1 ? DateTime.parse(row[1].toString()) : DateTime.now(),
      type: row.length > 2 ? row[2].toString() : 'Ingreso',
      description: row.length > 3 ? row[3].toString() : '',
      amountUSD: row.length > 4 ? double.tryParse(row[4].toString()) ?? 0.0 : 0.0,
      amountVES: row.length > 5 ? double.tryParse(row[5].toString()) ?? 0.0 : 0.0,
    );
  }

  List<dynamic> toList() {
    return [
      id,
      date.toIso8601String(),
      type,
      description,
      amountUSD.toStringAsFixed(2),
      amountVES.toStringAsFixed(2),
    ];
  }
}

class MovementRepository {
  final GoogleApiService googleApi;

  MovementRepository({required this.googleApi});

  Future<List<Movement>> getMovements() async {
    try {
      final response = await googleApi.sheetsApi.spreadsheets.values.get(
        AppConstants.spreadSheetId,
        'Movimientos!A2:F',
      );
      
      final List<dynamic> rows = response.values ?? [];
      return rows.map((row) => Movement.fromList(row as List<dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addMovement(Movement movement) async {
    try {
      final valueRange = sheets.ValueRange(values: [movement.toList()]);
      await googleApi.sheetsApi.spreadsheets.values.append(
        valueRange,
        AppConstants.spreadSheetId,
        'Movimientos!A:F',
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      rethrow;
    }
  }
}

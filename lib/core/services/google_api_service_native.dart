import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/foundation.dart';

class GoogleApiService {
  static const _spreadsheetId = '1PSLrL9OFdXh-HCwxI1JXdTFM8zL6vMwOx0Yj7rUQ10Y';
  static const _scopes = [sheets.SheetsApi.spreadsheetsScope];

  sheets.SheetsApi? _sheetsApi;
  bool get isInitialized => _sheetsApi != null;

  // SOLUCIÓN AL ERROR: Exponemos la API públicamente para que los repositorios la puedan usar
  sheets.SheetsApi get sheetsApi {
    if (_sheetsApi == null) {
      throw Exception(
        'GoogleApiService no está inicializado. Llama a init() primero.',
      );
    }
    return _sheetsApi!;
  }

  // Inicialización y lectura de credenciales incrustadas en el APK
  Future<void> init() async {
    if (_sheetsApi != null) return;
    try {
      final credentialsJson = await rootBundle.loadString(
        'assets/credentials.json',
      );
      final credentials = ServiceAccountCredentials.fromJson(credentialsJson);

      final client = await clientViaServiceAccount(credentials, _scopes);
      _sheetsApi = sheets.SheetsApi(client);
      debugPrint(
        '[GoogleApiService Native] Autenticación directa con Google Sheets exitosa.',
      );
    } catch (e) {
      debugPrint(
        '[GoogleApiService Native] Error inicializando credenciales: $e',
      );
      rethrow;
    }
  }

  // --- MÉTODOS BASE ---
  Future<List<List<Object?>>> getSheetData(String range) async {
    if (!isInitialized) await init();
    final response = await sheetsApi.spreadsheets.values.get(
      _spreadsheetId,
      range,
    );
    return response.values ?? [];
  }

  Future<void> appendRow(String range, List<Object?> row) async {
    if (!isInitialized) await init();
    final valueRange = sheets.ValueRange(values: [row]);
    await sheetsApi.spreadsheets.values.append(
      valueRange,
      _spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  Future<void> updateRow(String range, List<Object?> row) async {
    if (!isInitialized) await init();
    final valueRange = sheets.ValueRange(values: [row]);
    await sheetsApi.spreadsheets.values.update(
      valueRange,
      _spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  // --- MÉTODOS DE NEGOCIO ---
  Future<List<List<Object?>>> getProductos() => getSheetData('Productos!A2:G');

  Future<List<List<Object?>>> getVentas() => getSheetData('Ventas!A2:H');

  Future<void> postVenta(
    Map<String, dynamic> ventaData,
    List<dynamic> detalles,
  ) async {
    if (!isInitialized) await init();

    // 1. Escribir fila en la hoja Ventas
    final ventaRow = [
      ventaData['id_venta'],
      ventaData['fecha'],
      ventaData['total_usd'],
      ventaData['total_ves'],
      ventaData['tasa_cambio'],
      ventaData['pdf_url'] ?? " ",
      jsonEncode(ventaData['metodos_pago']),
      ventaData['detalles'] ?? " ",
    ];
    await appendRow('Ventas!A:H', ventaRow);

    // 2. Escribir filas múltiples en DetalleVentas
    final detalleRows = detalles
        .map(
          (d) => [
            ventaData['id_venta'],
            d['id_producto'],
            d['nombre_producto'],
            d['cantidad'],
            d['precio_unitario_usd'],
            d['subtotal_usd'],
          ],
        )
        .toList();

    final valueRange = sheets.ValueRange(values: detalleRows);
    await sheetsApi.spreadsheets.values.append(
      valueRange,
      _spreadsheetId,
      'DetalleVentas!A:F',
      valueInputOption: 'USER_ENTERED',
    );
  }
}

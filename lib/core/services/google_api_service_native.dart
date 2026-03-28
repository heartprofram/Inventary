import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';

class GoogleApiService {
  sheets.SheetsApi? _sheetsApi;

  Future<void> init() async {
    try {
      debugPrint('[Nativo] Conectando a Google Sheets API mediante Service Account...');
      
      // 1. Cargar credenciales desde archivos de assets
      final String credentialsJson = await rootBundle.loadString('assets/credentials.json');
      final Map<String, dynamic> credentialsMap = json.decode(credentialsJson);
      final credentials = ServiceAccountCredentials.fromJson(credentialsMap);
      final scopes = [sheets.SheetsApi.spreadsheetsScope];
      
      // 2. Intentar autenticación (esta es la parte lenta/dependiente de red)
      final client = await clientViaServiceAccount(credentials, scopes);
      
      // 3. Crear el cliente API
      _sheetsApi = sheets.SheetsApi(client);
      debugPrint('[Nativo] GoogleApiService inicializado exitosamente.');
    } catch (e) {
      // Si falla, el API se mantiene como null y los repositorios usarán el modo offline por defecto
      debugPrint('[Nativo] Error en GoogleApiService.init(): $e');
      debugPrint('[Nativo] Continuando en modo Offline debido a fallo de red inicial.');
    }
  }

  sheets.SheetsApi get sheetsApi {
    if (_sheetsApi == null) {
      throw Exception('SheetsApi no inicializada o desconectada. Operando en modo Offline...');
    }
    return _sheetsApi!;
  }
}


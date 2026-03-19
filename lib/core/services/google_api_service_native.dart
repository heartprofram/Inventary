import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';

class GoogleApiService {
  sheets.SheetsApi? _sheetsApi;

  Future<void> init() async {
    print('MODO NATIVO: Conectando directo a Google Sheets...');
    
    // Leer credenciales desde assets
    final String credentialsJson = await rootBundle.loadString('assets/credentials.json');
    final Map<String, dynamic> credentialsMap = json.decode(credentialsJson);
    
    final credentials = ServiceAccountCredentials.fromJson(credentialsMap);
    
    final scopes = [sheets.SheetsApi.spreadsheetsScope];
    
    // Obtener cliente autenticado
    final client = await clientViaServiceAccount(credentials, scopes);
    
    _sheetsApi = sheets.SheetsApi(client);
    print('MODO NATIVO: GoogleApiService inicializado correctamente.');
  }

  sheets.SheetsApi get sheetsApi {
    if (_sheetsApi == null) {
      throw Exception('SheetsApi no está inicializada. Asegúrate de llamar a init() primero.');
    }
    return _sheetsApi!;
  }
}

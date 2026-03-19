import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import '../constants/app_constants.dart';

class GoogleApiService {
  static const _scopes = [
    sheets.SheetsApi.spreadsheetsScope,
  ];

  AutoRefreshingAuthClient? _client;
  sheets.SheetsApi? _sheetsApi;

  Future<void> init() async {
    try {
      // Cargar el archivo JSON de credenciales desde los assets
      final credentialsJsonString = await rootBundle.loadString(AppConstants.credentialsFile);
      final credentialsContent = json.decode(credentialsJsonString);
      
      final credentials = ServiceAccountCredentials.fromJson(credentialsContent);
      
      _client = await clientViaServiceAccount(credentials, _scopes);
      _sheetsApi = sheets.SheetsApi(_client!);
      
      print('Google APIs inicializadas de manera exitosa');
    } catch (e) {
      print('Error al inicializar Google APIs: $e');
      rethrow;
    }
  }

  sheets.SheetsApi get sheetsApi {
    if (_sheetsApi == null) {
      throw Exception('SheetsApi no está inicializada. Llama a init() primero.');
    }
    return _sheetsApi!;
  }
}

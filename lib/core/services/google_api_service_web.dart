import 'package:googleapis/sheets/v4.dart' as sheets;

class GoogleApiService {
  bool get isInitialized => true;

  Future<void> init() async {
    print('MODO WEB: GoogleApiService inicializado (Sin conexión directa, se usará servidor Python)');
  }

  sheets.SheetsApi get sheetsApi {
    throw Exception('No se puede usar sheetsApi directamente en Web. Usa el servidor Python (Dio).');
  }
}

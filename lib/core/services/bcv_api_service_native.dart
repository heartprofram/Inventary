import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../features/settings/domain/exchange_rate.dart';

class BcvApiService {
  final Dio _dio = Dio();

  Future<ExchangeRate> getCurrentRate() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      Response response;

      if (kIsWeb) {
        // En la Web: usamos el servidor de Python (localhost) para evitar el bloqueo de CORS
        response = await _dio.get(
          'http://localhost:8081/api/tasa?t=$timestamp',
          options: Options(headers: {'Cache-Control': 'no-cache'}),
        );
      } else {
        // En el APK (Android): Nos conectamos DIRECTO a la API original
        // Esto hace que la app móvil sea 100% independiente
        response = await _dio.get(
          'https://ve.dolarapi.com/v1/dolares/oficial',
          options: Options(headers: {'Cache-Control': 'no-cache'}),
        );
      }

      if (response.statusCode == 200) {
        final data = response.data;
        double rate = 0.0;
        try {
          rate = (data['promedio'] ?? 0.0).toDouble();
        } catch (_) {
          rate = 0.0;
        }

        return ExchangeRate(rate: rate, lastUpdated: DateTime.now());
      } else {
        throw Exception(
          'Error al obtener tasa. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Excepción al conectar con la API del BCV: $e');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../features/settings/domain/exchange_rate.dart';

class BcvApiService {
  Future<ExchangeRate> getCurrentRate() async {
    try {
      if (kIsWeb) {
        // LÓGICA WEB: Consulta a tu servidor Python (servidor.py)
        final response = await http.get(Uri.parse('http://localhost:8081/api/tasa'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return ExchangeRate(rate: (data['promedio'] as num).toDouble(), lastUpdated: DateTime.now());
        }
        throw Exception('Error al obtener tasa desde el servidor Web');
      } else {
        // LÓGICA APK/NATIVA: Consulta a DolarAPI directamente de forma autónoma
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final url = Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial?t=$timestamp');
        final response = await http.get(url, headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return ExchangeRate(rate: (data['promedio'] as num).toDouble(), lastUpdated: DateTime.now());
        }
        throw Exception('Error al obtener tasa desde DolarAPI');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener tasa: $e');
    }
  }
}

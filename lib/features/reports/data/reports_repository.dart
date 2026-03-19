import '../../../core/services/google_api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../sales/domain/sale.dart';

class ReportsRepository {
  final GoogleApiService googleApi;

  ReportsRepository({required this.googleApi});

  Future<List<Sale>> getDailySales() async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final response = await googleApi.sheetsApi.spreadsheets.values.get(
        AppConstants.spreadSheetId,
        'Ventas!A2:G',
      );

      final List<dynamic> rows = response.values ?? [];
      final List<Sale> dailySales = [];

      for (var row in rows) {
        final rowList = row as List<dynamic>;
        if (rowList.length >= 5) {
          final dateStr = rowList[1].toString();
          if (dateStr.startsWith(todayStr)) {
            final paymentMethod = rowList.length > 6 ? rowList[6].toString() : '';
            final sale = Sale(
              id: rowList[0].toString(),
              date: DateTime.parse(dateStr),
              exchangeRate: double.tryParse(rowList[4].toString()) ?? 0.0,
              details: [],
              paymentMethod: paymentMethod.isNotEmpty
                  ? paymentMethod
                  : PaymentMethods.efectivoUsd,
            )..overrideTotals(
                double.tryParse(rowList[2].toString()) ?? 0.0,
                double.tryParse(rowList[3].toString()) ?? 0.0,
              );
            dailySales.add(sale);
          }
        }
      }

      return dailySales;
    } catch (e) {
      throw Exception('Error al obtener las ventas del día: $e');
    }
  }
}

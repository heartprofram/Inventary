class ExchangeRate {
  final String currencyFrom;
  final String currencyTo;
  final double rate;
  final DateTime lastUpdated;

  const ExchangeRate({
    this.currencyFrom = 'USD',
    this.currencyTo = 'VES',
    required this.rate,
    required this.lastUpdated,
  });
}

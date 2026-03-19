class Product {
  final String id;
  final String name;
  final String description;
  final double costPriceUSD;
  final double salePriceUSD;
  final int stockQuantity;
  final String barCode;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.costPriceUSD,
    required this.salePriceUSD,
    required this.stockQuantity,
    required this.barCode,
  });

  // Factory methods from/to Google Sheets rows mapping can be added here
}

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'costPriceUSD': costPriceUSD,
      'salePriceUSD': salePriceUSD,
      'stockQuantity': stockQuantity,
      'barCode': barCode,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      costPriceUSD: (json['costPriceUSD'] as num).toDouble(),
      salePriceUSD: (json['salePriceUSD'] as num).toDouble(),
      stockQuantity: json['stockQuantity'] as int,
      barCode: json['barCode'],
    );
  }
}

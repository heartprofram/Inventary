class Payment {
  final String method;
  final double amount;

  Payment({
    required this.method,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'amount': amount,
    };
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      method: json['method'],
      amount: json['amount'],
    );
  }
}

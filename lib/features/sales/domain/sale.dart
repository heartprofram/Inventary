class SaleDetail {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPriceUSD;

  SaleDetail({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceUSD,
  });

  double get subtotalUSD => quantity * unitPriceUSD;
}

// Métodos de pago disponibles
class PaymentMethods {
  static const String efectivoUsd = 'efectivo_usd';
  static const String efectivoVes = 'efectivo_ves';
  static const String pagoMovil = 'pago_movil';
  static const String transferencia = 'transferencia';
  static const String puntoDeVenta = 'punto_de_venta';
  static const String pendiente = 'pendiente';

  static const Map<String, String> labels = {
    efectivoUsd: 'Efectivo (\$)',
    efectivoVes: 'Efectivo (Bs)',
    pagoMovil: 'Pago Movil',
    transferencia: 'Transferencia',
    puntoDeVenta: 'Tarjeta (Punto)',
    pendiente: 'Pago Pendiente',
  };

  String label(String method) => labels[method] ?? method;
}

String get paymentMethodLabel => payments.isEmpty ? 'Efectivo' : payments.first.method;

class Sale {
  final String id;
  final DateTime date;
  final double exchangeRate;
  final List<SaleDetail> details;
  final List<Payment> payments;
  final String? debtorName;

  double _totalUSDTmp = -1;
  double _totalVESTmp = -1;

  Sale({
    required this.id,
    required this.date,
    required this.exchangeRate,
    required this.details,
    required this.payments,
    this.debtorName,
  });

  // Metodo para inyectar desde Repo
  void overrideTotals(double tUsd, double tVes) {
    _totalUSDTmp = tUsd;
    _totalVESTmp = tVes;
  }

  double get totalUSD {
    if (_totalUSDTmp >= 0) return _totalUSDTmp;
    return details.fold(0.0, (sum, item) => sum + item.subtotalUSD);
  }

  double get totalVES {
    if (_totalVESTmp >= 0) return _totalVESTmp;
    return totalUSD * exchangeRate;
  }

  Map<String, dynamic> toJson() {
    return {
      'id_venta': id,
      'fecha': date.toIso8601String(),
      'total_usd': totalUSD,
      'total_ves': totalVES,
      'tasa_cambio': exchangeRate,
      'metodos_pago': payments.map((p) => p.toJson()).toList(),
      'detalles': debtorName ?? '',
      'detalles_productos': details.map((d) => {
        'id_producto': d.productId,
        'nombre_producto': d.productName,
        'cantidad': d.quantity,
        'precio_unitario_usd': d.unitPriceUSD,
        'subtotal_usd': d.subtotalUSD,
      }).toList(),
    };
  }
}

class Payment {
  final String method;
  final double amount;

  Payment({
    required this.method,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'method': method,
    'amount': amount,
  };

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      method: json['method'],
      amount: json['amount'],
    );
  }
}

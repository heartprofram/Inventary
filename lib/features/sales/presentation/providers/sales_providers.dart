import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/pdf_invoice_generator.dart';
import '../../domain/sale.dart';
import '../providers/cart_provider.dart';
import '../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../inventory/domain/product.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

// salesRepositoryProvider ya está definido en core_providers.dart

import 'package:inventary/features/sales/presentation/providers/payment_provider.dart';

// Async Notifier para procesar el Checkout
class CheckoutNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> processCheckout({bool printInvoice = true}) async {
    state = const AsyncValue.loading();
    
    try {
      final cartItems = ref.read(cartProvider);
      if (cartItems.isEmpty) return;

      final exchangeRateState = ref.read(exchangeRateProvider);
      final currentExchangeRate = exchangeRateState.value?.rate ?? 36.0;
      final payments = ref.read(paymentsProvider);
      final debtorName = ref.read(debtorNameProvider);

      final sale = Sale(
        id: 'VEN-${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        exchangeRate: currentExchangeRate,
        details: cartItems,
        payments: payments,
        debtorName: debtorName,
      );

      // 1. Generar Factura en PDF (Bytes) - Opcional
      Uint8List? pdfBytes;
      if (printInvoice) {
        if (sale.payments.any((p) => p.method == PaymentMethods.pendiente)) {
          // Factura simplificada para pagos pendientes
          pdfBytes = await PdfInvoiceGenerator.generateSimpleInvoice(sale);
        } else {
          pdfBytes = await PdfInvoiceGenerator.generateInvoice(sale);
        }
      }

      // 2. Procesar venta en Sheets y descontar Stock
      final salesRepo = ref.read(salesRepositoryProvider);
      await salesRepo.processSale(sale);

      // 3. Descargar/Mostrar el PDF en el navegador - Opcional
      if (printInvoice && pdfBytes != null) {
        await Printing.sharePdf(bytes: pdfBytes, filename: 'Factura_${sale.id}.pdf');
      }

      // 4. Limpiar el carrito, resetear método de pago y actualizar el inventario en UI
      ref.read(cartProvider.notifier).clear();
      ref.read(paymentsProvider.notifier).clearPayments();
      ref.read(debtorNameProvider.notifier).state = null;
      ref.read(inventoryProvider.notifier).refresh();
      
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final checkoutProvider = AsyncNotifierProvider<CheckoutNotifier, void>(() {
  return CheckoutNotifier();
});

// Provider para el término de búsqueda
final searchQueryProvider = StateProvider<String>((ref) => '');

// Provider para los productos filtrados
final filteredInventoryProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final inventoryAsync = ref.watch(inventoryProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();

  return inventoryAsync.whenData((products) {
    // Primero filtramos los que tengan stock disponible (como en la pantalla original)
    final availableProducts = products.where((p) => p.stockQuantity > 0).toList();
    
    // Luego filtramos por el término de búsqueda si existe
    if (searchQuery.isEmpty) return availableProducts;

    return availableProducts.where((product) {
      return product.name.toLowerCase().contains(searchQuery);
    }).toList();
  });
});

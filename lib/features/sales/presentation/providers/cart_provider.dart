import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/sale.dart';
import '../../../inventory/domain/product.dart';

class CartNotifier extends Notifier<List<SaleDetail>> {
  @override
  List<SaleDetail> build() {
    return [];
  }

  // Agregar un producto al carrito
  void addProduct(Product product) {
    final existingIndex = state.indexWhere((item) => item.productId == product.id);

    if (existingIndex >= 0) {
      // Si ya existe, incrementar cantidad
      final currentItem = state[existingIndex];
      if (currentItem.quantity < product.stockQuantity) {
        state = [
          ...state.sublist(0, existingIndex),
          SaleDetail(
            productId: currentItem.productId,
            productName: currentItem.productName,
            quantity: currentItem.quantity + 1,
            unitPriceUSD: currentItem.unitPriceUSD,
          ),
          ...state.sublist(existingIndex + 1),
        ];
      }
    } else {
      // Si no existe, agregar con cantidad 1
      if (product.stockQuantity > 0) {
        state = [
          ...state,
          SaleDetail(
            productId: product.id,
            productName: product.name,
            quantity: 1,
            unitPriceUSD: product.salePriceUSD,
          )
        ];
      }
    }
  }

  // Reducir o eliminar cantidad
  void removeProduct(String productId) {
    final existingIndex = state.indexWhere((item) => item.productId == productId);
    if (existingIndex >= 0) {
      final currentItem = state[existingIndex];
      if (currentItem.quantity > 1) {
        state = [
          ...state.sublist(0, existingIndex),
          SaleDetail(
            productId: currentItem.productId,
            productName: currentItem.productName,
            quantity: currentItem.quantity - 1,
            unitPriceUSD: currentItem.unitPriceUSD,
          ),
          ...state.sublist(existingIndex + 1),
        ];
      } else {
        // Eliminar del todo si la cantidad llega a 0
        state = state.where((item) => item.productId != productId).toList();
      }
    }
  }

  // Editar precio unitario en dólares de un producto existente
  void editProductPrice(String productId, double newPriceUSD) {
    if (newPriceUSD < 0) return;
    final existingIndex = state.indexWhere((item) => item.productId == productId);
    if (existingIndex >= 0) {
      final currentItem = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        SaleDetail(
          productId: currentItem.productId,
          productName: currentItem.productName,
          quantity: currentItem.quantity,
          unitPriceUSD: newPriceUSD,
        ),
        ...state.sublist(existingIndex + 1),
      ];
    }
  }

  // Vaciar carrito
  void clear() {
    state = [];
  }

  // Obtener Total
  double get totalCartUSD {
    return state.fold(0.0, (sum, item) => sum + item.subtotalUSD);
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<SaleDetail>>(() {
  return CartNotifier();
});

// Extension para pending payments
extension CartNotifierExt on CartNotifier {
  void addProductByDetail(SaleDetail detail) {
    final existingIndex = state.indexWhere((item) => item.productId == detail.productId);
    if (existingIndex >= 0) {
      final currentItem = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        SaleDetail(
          productId: currentItem.productId,
          productName: currentItem.productName,
          quantity: currentItem.quantity + detail.quantity,
          unitPriceUSD: currentItem.unitPriceUSD,
        ),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, detail];
    }
  }
}

// Provider para el método de pago seleccionado
final paymentMethodProvider = StateProvider<String>((ref) {
  return PaymentMethods.efectivoUsd;
});


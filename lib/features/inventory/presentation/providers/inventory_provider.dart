import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/product.dart';

// Definimos un Notifier Asíncrono para manejar la lista de productos
class InventoryNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    // Cuando el provider se construye (o sea, la primera vez que se escucha),
    // carga los productos desde nuestro repositorio de Google Sheets.
    return ref.watch(productRepositoryProvider).getProducts();
  }

  // Método para refrescar manualmente
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(productRepositoryProvider).getProducts());
  }

  // Agregar producto e invalidar la lista
  Future<void> addProduct(Product product) async {
    try {
      await ref.read(productRepositoryProvider).addProduct(product);
      // Forzamos la recarga desde Google Sheets
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  // Obtener Valor Total del Inventario
  double get totalInventoryValueVES {
    // Calculamos asumiendo que ya hay data (estado es data)
    final products = state.valueOrNull ?? [];
    // En el futuro inyectaremos el ExchangeRateProvider aquí para calcular a VES
    // Por ahora sumamos solo el costo USD para demostrar la reactividad
    return products.fold(0.0, (sum, item) => sum + (item.costPriceUSD * item.stockQuantity));
  }
}

// Declaración Global del Provider (Notifier)
final inventoryProvider = AsyncNotifierProvider<InventoryNotifier, List<Product>>(() {
  return InventoryNotifier();
});

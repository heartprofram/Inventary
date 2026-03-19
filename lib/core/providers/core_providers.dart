import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/inventory/data/product_repository.dart';
import '../../features/sales/data/sales_repository.dart';
import '../services/google_api_service.dart';

// Proveedor del servicio de Google APIs
final googleApiServiceProvider = Provider<GoogleApiService>((ref) {
  throw UnimplementedError('Debe inicializarse en main.dart');
});

// Proveedor del Repositorio de Productos (ahora usa Google Api directa)
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final googleApi = ref.watch(googleApiServiceProvider);
  return ProductRepository(googleApi: googleApi);
});

// Proveedor del Repositorio de Ventas
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  return SalesRepository(googleApi: googleApi, productRepository: productRepo);
});

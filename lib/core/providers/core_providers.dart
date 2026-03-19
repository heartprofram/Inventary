import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/google_api_service.dart';
import '../../features/inventory/data/product_repository.dart';
import '../../features/sales/data/sales_repository.dart';
import '../../features/reports/data/reports_repository.dart';
import '../../features/reports/data/movement_repository.dart';

// Proveedor de GoogleApiService (Simulado en Web, Real en Android)
final googleApiServiceProvider = Provider<GoogleApiService>((ref) {
  throw UnimplementedError('GoogleApiService no ha sido inicializado mediante overrideWithValue');
});

// Proveedor global de Dio para las peticiones HTTP al servidor Python
final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

// Repositorio de Productos (Híbrido)
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  return ProductRepository(dio: dio, googleApi: googleApi);
});

// Repositorio de Ventas (Híbrido)
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  final dio = ref.watch(dioProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  return SalesRepository(
    dio: dio, 
    googleApi: googleApi,
    productRepository: productRepo,
  );
});

// Repositorio de Reportes (Híbrido)
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  return ReportsRepository(dio: dio, googleApi: googleApi);
});

// Repositorio de Movimientos (Híbrido)
final movementRepositoryProvider = Provider<MovementRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  return MovementRepository(dio: dio, googleApi: googleApi);
});
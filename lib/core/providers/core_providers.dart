import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/google_api_service.dart';
import '../services/local_storage_service.dart';
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

// Servicio de Almacenamiento Local (Cola Offline)
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

// Repositorio de Productos (Híbrido)
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  return ProductRepository(dio: dio, googleApi: googleApi, localStorageService: localStorage);
});

// Repositorio de Ventas (Híbrido)
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  final dio = ref.watch(dioProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  return SalesRepository(
    dio: dio,
    googleApi: googleApi,
    productRepository: productRepo,
    localStorageService: localStorage,
  );
});

// Repositorio de Reportes (Híbrido)
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  return ReportsRepository(dio: dio, googleApi: googleApi, localStorageService: localStorage);
});

// Repositorio de Movimientos (Híbrido)
final movementRepositoryProvider = Provider<MovementRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final googleApi = ref.watch(googleApiServiceProvider);
  final localStorage = ref.watch(localStorageServiceProvider);
  return MovementRepository(
    dio: dio,
    googleApi: googleApi,
    localStorageService: localStorage,
  );
});
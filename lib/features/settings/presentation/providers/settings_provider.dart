import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/bcv_api_service.dart';
import '../../domain/exchange_rate.dart';

// Proveedor del Servicio API BCV
final bcvApiServiceProvider = Provider<BcvApiService>((ref) {
  return BcvApiService();
});

// Proveedor Asíncrono para la Tasa de Cambio
class ExchangeRateNotifier extends AsyncNotifier<ExchangeRate> {
  static const _rateKey = 'manual_exchange_rate';
  static const _isAutoKey = 'is_auto_exchange_rate';
  static const _cachedRateKey =
      'cached_exchange_rate'; // NUEVA CLAVE PARA LA CACHÉ OFFLINE

  Timer? _refreshTimer;

  @override
  Future<ExchangeRate> build() async {
    ref.onDispose(() => _refreshTimer?.cancel());
    return _loadInitialRate();
  }

  Future<ExchangeRate> _loadInitialRate() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuto = prefs.getBool(_isAutoKey) ?? true;

    if (isAuto) {
      try {
        final rate = await ref.read(bcvApiServiceProvider).getCurrentRate();

        // 🔴 CORRECCIÓN: Guardamos la tasa automática exitosa en la memoria del teléfono
        await prefs.setDouble(_cachedRateKey, rate.rate);

        _startTimer();
        return rate;
      } catch (e) {
        // 🔴 CORRECCIÓN: Si falla la API (No hay internet), buscamos la última tasa de la caché
        final lastKnownRate =
            prefs.getDouble(_cachedRateKey) ??
            prefs.getDouble(_rateKey) ??
            36.0;
        return ExchangeRate(rate: lastKnownRate, lastUpdated: DateTime.now());
      }
    } else {
      final manualRate =
          prefs.getDouble(_rateKey) ?? prefs.getDouble(_cachedRateKey) ?? 36.0;
      return ExchangeRate(rate: manualRate, lastUpdated: DateTime.now());
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 60), (timer) {
      _loadLatestRateSilently();
    });
  }

  Future<void> _loadLatestRateSilently() async {
    final prefs = await SharedPreferences.getInstance();
    final isAuto = prefs.getBool(_isAutoKey) ?? true;
    if (!isAuto) {
      _refreshTimer?.cancel();
      return;
    }

    try {
      final rate = await ref.read(bcvApiServiceProvider).getCurrentRate();

      // 🔴 CORRECCIÓN: Si la actualización en segundo plano es exitosa, también actualizamos la caché
      await prefs.setDouble(_cachedRateKey, rate.rate);

      state = AsyncValue.data(rate);
    } catch (_) {
      // Silently fail on background refresh
    }
  }

  Future<void> fetchBcvRate() async {
    state = const AsyncValue.loading();
    try {
      final rate = await ref.read(bcvApiServiceProvider).getCurrentRate();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isAutoKey, true);

      // 🔴 CORRECCIÓN: Guardamos también cuando el usuario presiona actualizar manualmente
      await prefs.setDouble(_cachedRateKey, rate.rate);

      state = AsyncValue.data(rate);
      _startTimer();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> setManualRate(double newRate) async {
    _refreshTimer?.cancel();
    state = const AsyncValue.loading();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble(_rateKey, newRate);
    await prefs.setDouble(
      _cachedRateKey,
      newRate,
    ); // Sincronizamos la caché con la manual
    await prefs.setBool(_isAutoKey, false);

    state = AsyncValue.data(
      ExchangeRate(rate: newRate, lastUpdated: DateTime.now()),
    );
  }
}

final exchangeRateProvider =
    AsyncNotifierProvider<ExchangeRateNotifier, ExchangeRate>(() {
      return ExchangeRateNotifier();
    });

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
        _startTimer();
        return rate;
      } catch (e) {
        // Fallback a manual si falla la API
        final manualRate = prefs.getDouble(_rateKey) ?? 36.0;
        return ExchangeRate(rate: manualRate, lastUpdated: DateTime.now());
      }
    } else {
      final manualRate = prefs.getDouble(_rateKey) ?? 36.0;
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
      state = AsyncValue.data(rate);
    } catch (_) {
      // Silently fail on background refresh
    }
  }

  Future<void> fetchBcvRate() async {
    state = const AsyncValue.loading();
    try {
      final rate = await ref.read(bcvApiServiceProvider).getCurrentRate();
      state = AsyncValue.data(rate);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isAutoKey, true);
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
    await prefs.setBool(_isAutoKey, false);
    
    state = AsyncValue.data(ExchangeRate(rate: newRate, lastUpdated: DateTime.now()));
  }
}

final exchangeRateProvider = AsyncNotifierProvider<ExchangeRateNotifier, ExchangeRate>(() {
  return ExchangeRateNotifier();
});

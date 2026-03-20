import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de Cola de Sincronización Local.
/// 
/// Almacena ventas y movimientos que fallaron al enviarse a la red,
/// para reintentarlos cuando la conexión se restaure.
class LocalStorageService {
  static const _pendingSalesKey = 'pending_sales_queue';
  static const _pendingMovementsKey = 'pending_movements_queue';

  // ─── Ventas Pendientes ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingSalesKey) ?? [];
      return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('[LocalStorage] Error leyendo ventas pendientes: $e');
      return [];
    }
  }

  Future<void> addPendingSale(Map<String, dynamic> saleJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingSalesKey) ?? [];
      raw.add(jsonEncode(saleJson));
      await prefs.setStringList(_pendingSalesKey, raw);
      debugPrint('[OfflineQueue] Venta guardada en cola: ${saleJson['id_venta']}');
    } catch (e) {
      debugPrint('[LocalStorage] Error guardando venta pendiente: $e');
    }
  }

  Future<void> removePendingSale(String idVenta) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingSalesKey) ?? [];
      raw.removeWhere((e) {
        final map = jsonDecode(e) as Map<String, dynamic>;
        return map['id_venta'] == idVenta;
      });
      await prefs.setStringList(_pendingSalesKey, raw);
      debugPrint('[OfflineQueue] Venta sincronizada y removida: $idVenta');
    } catch (e) {
      debugPrint('[LocalStorage] Error removiendo venta pendiente: $e');
    }
  }

  // ─── Movimientos Pendientes ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingMovements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingMovementsKey) ?? [];
      return raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('[LocalStorage] Error leyendo movimientos pendientes: $e');
      return [];
    }
  }

  Future<void> addPendingMovement(Map<String, dynamic> movementJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingMovementsKey) ?? [];
      raw.add(jsonEncode(movementJson));
      await prefs.setStringList(_pendingMovementsKey, raw);
      debugPrint('[OfflineQueue] Movimiento guardado en cola: ${movementJson['id']}');
    } catch (e) {
      debugPrint('[LocalStorage] Error guardando movimiento pendiente: $e');
    }
  }

  Future<void> removePendingMovement(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_pendingMovementsKey) ?? [];
      raw.removeWhere((e) {
        final map = jsonDecode(e) as Map<String, dynamic>;
        return map['id'] == id;
      });
      await prefs.setStringList(_pendingMovementsKey, raw);
      debugPrint('[OfflineQueue] Movimiento sincronizado y removido: $id');
    } catch (e) {
      debugPrint('[LocalStorage] Error removiendo movimiento pendiente: $e');
    }
  }

  // ─── Contadores ──────────────────────────────────────────────────────────

  Future<int> getPendingCount() async {
    final sales = await getPendingSales();
    final movements = await getPendingMovements();
    return sales.length + movements.length;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSalesKey);
    await prefs.remove(_pendingMovementsKey);
  }
}

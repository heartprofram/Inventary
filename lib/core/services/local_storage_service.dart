import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Servicio de Cola de Sincronización Local (Migrado a Hive para soporte PWA robusto).
/// 
/// Almacena ventas y movimientos que fallaron al enviarse a la red,
/// para reintentarlos cuando la conexión se restaure.
class LocalStorageService {
  static const String _salesBoxName = 'sales_queue';
  static const String _movementsBoxName = 'movements_queue';

  // ─── Ventas Pendientes ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingSales() async {
    try {
      final box = Hive.box(_salesBoxName);
      return box.values.map((e) {
        if (e is String) return jsonDecode(e) as Map<String, dynamic>;
        return Map<String, dynamic>.from(e as Map);
      }).toList();
    } catch (e) {
      debugPrint('[LocalStorage] Error leyendo ventas pendientes: $e');
      return [];
    }
  }

  Future<void> addPendingSale(Map<String, dynamic> saleJson) async {
    try {
      final box = Hive.box(_salesBoxName);
      // Usamos el ID de la venta como llave para evitar duplicados
      await box.put(saleJson['id_venta'], saleJson);
      debugPrint('[OfflineQueue] Venta guardada en Hive: ${saleJson['id_venta']}');
    } catch (e) {
      debugPrint('[LocalStorage] Error guardando venta en Hive: $e');
    }
  }

  Future<void> removePendingSale(String idVenta) async {
    try {
      final box = Hive.box(_salesBoxName);
      await box.delete(idVenta);
      debugPrint('[OfflineQueue] Venta removida de Hive: $idVenta');
    } catch (e) {
      debugPrint('[LocalStorage] Error removiendo venta de Hive: $e');
    }
  }

  // ─── Movimientos Pendientes ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingMovements() async {
    try {
      final box = await _getMovementBox();
      return box.values.map((e) {
        if (e is String) return jsonDecode(e) as Map<String, dynamic>;
        return Map<String, dynamic>.from(e as Map);
      }).toList();
    } catch (e) {
      debugPrint('[LocalStorage] Error leyendo movimientos: $e');
      return [];
    }
  }

  Future<void> addPendingMovement(Map<String, dynamic> movementJson) async {
    try {
      final box = await _getMovementBox();
      await box.put(movementJson['id'], movementJson);
    } catch (e) {
      debugPrint('[LocalStorage] Error guardando movimiento: $e');
    }
  }

  Future<void> removePendingMovement(String id) async {
    try {
      final box = await _getMovementBox();
      await box.delete(id);
    } catch (e) {
      debugPrint('[LocalStorage] Error removiendo movimiento: $e');
    }
  }

  // Helper para asegurar que la caja esté abierta (Movements no se abrió en main)
  Future<Box> _getMovementBox() async {
    if (!Hive.isBoxOpen(_movementsBoxName)) {
      return await Hive.openBox(_movementsBoxName);
    }
    return Hive.box(_movementsBoxName);
  }

  // ─── Contadores ──────────────────────────────────────────────────────────

  Future<int> getPendingCount() async {
    final salesBox = Hive.box(_salesBoxName);
    final movBox = await _getMovementBox();
    return salesBox.length + movBox.length;
  }

  Future<void> clearAll() async {
    final salesBox = Hive.box(_salesBoxName);
    final movBox = await _getMovementBox();
    await salesBox.clear();
    await movBox.clear();
  }
}

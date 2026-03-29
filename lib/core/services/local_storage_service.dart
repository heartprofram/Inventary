import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _salesQueue = 'sales_queue';
  static const String _movementsQueue = 'movements_queue';
  static const String _inventoryQueue = 'inventory_queue';
  static const String _defaultCacheBox = 'inventory_box';

  // ─── MÉTODOS DE CACHÉ GENÉRICA (SOLUCIÓN VIOLACIÓN DE CAPAS) ───────────────

  // Guarda información en una caja específica de Hive
  Future<void> saveCache(String boxName, String key, dynamic data) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    await Hive.box(boxName).put(key, data);
  }

  // Recupera información de una caja específica de Hive
  Future<dynamic> getCache(String boxName, String key, {dynamic defaultValue}) async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    return Hive.box(boxName).get(key, defaultValue: defaultValue);
  }
  
  // ─── GESTIÓN DE COLAS ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPendingSales() async {
    final box = await _getBox(_salesQueue);
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addPendingSale(Map<String, dynamic> sale) async {
    final box = await _getBox(_salesQueue);
    await box.put(sale['id_venta'], sale);
  }

  Future<void> removePendingSale(String id) async {
    final box = await _getBox(_salesQueue);
    await box.delete(id);
  }

  Future<List<Map<String, dynamic>>> getPendingMovements() async {
    final box = await _getBox(_movementsQueue);
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addPendingMovement(Map<String, dynamic> mov) async {
    final box = await _getBox(_movementsQueue);
    await box.put(mov['id'], mov);
  }

  Future<void> removePendingMovement(String id) async {
    final box = await _getBox(_movementsQueue);
    await box.delete(id);
  }

  Future<List<Map<String, dynamic>>> getPendingInventoryUpdates() async {
    final box = await _getBox(_inventoryQueue);
    return box.keys.map((key) {
      final val = Map<String, dynamic>.from(box.get(key) as Map);
      val['queue_key'] = key;
      return val;
    }).toList();
  }

  Future<void> addPendingInventoryUpdate(String productId, int newStock) async {
    final box = await _getBox(_inventoryQueue);
    await box.add({'productId': productId, 'newStock': newStock});
  }

  Future<void> removePendingInventoryUpdate(dynamic key) async {
    final box = await _getBox(_inventoryQueue);
    await box.delete(key);
  }

  Future<int> getPendingCount() async {
    final b1 = await _getBox(_salesQueue);
    final b2 = await _getBox(_movementsQueue);
    final b3 = await _getBox(_inventoryQueue);
    return b1.length + b2.length + b3.length;
  }

  Future<Box> _getBox(String name) async {
    return Hive.isBoxOpen(name) ? Hive.box(name) : await Hive.openBox(name);
  }
}

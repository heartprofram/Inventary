import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _salesQueue = 'sales_queue';
  static const String _movementsQueue = 'movements_queue';
  static const String _inventoryQueue = 'inventory_queue';
  static const String _paymentsQueue = 'payments_queue';
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

  Future<void> addPendingInventoryUpdate(dynamic update) async {
    final box = await _getBox(_inventoryQueue);
    await box.add(update);
  }


  Future<void> removePendingInventoryUpdate(dynamic key) async {
    final box = await _getBox(_inventoryQueue);
    await box.delete(key);
  }

  Future<List<Map<String, dynamic>>> getPendingPaymentUpdates() async {
    final box = await _getBox(_paymentsQueue);
    return box.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> addPendingPaymentUpdate(String idVenta, List<Map<String, dynamic>> payments) async {
    final box = await _getBox(_paymentsQueue);
    await box.put(idVenta, {'id_venta': idVenta, 'metodos_pago': payments});
  }

  Future<void> removePendingPaymentUpdate(String idVenta) async {
    final box = await _getBox(_paymentsQueue);
    await box.delete(idVenta);
  }

  Future<int> getPendingCount() async {
    final b1 = await _getBox(_salesQueue);
    final b2 = await _getBox(_movementsQueue);
    final b3 = await _getBox(_inventoryQueue);
    final b4 = await _getBox(_paymentsQueue);
    return b1.length + b2.length + b3.length + b4.length;
  }

  Future<Box> _getBox(String name) async {
    return Hive.isBoxOpen(name) ? Hive.box(name) : await Hive.openBox(name);
  }

  // --- MÉTODOS EXCLUSIVOS PARA EDICIÓN DE PRODUCTOS OFFLINE ---
  Future<void> addPendingProductEdit(Map<String, dynamic> productMap) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList('pending_product_edits') ?? [];
    current.removeWhere((item) => jsonDecode(item)['id'] == productMap['id']);
    current.add(jsonEncode(productMap));
    await prefs.setStringList('pending_product_edits', current);
  }

  Future<List<Map<String, dynamic>>> getPendingProductEdits() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList('pending_product_edits') ?? [];
    return current.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> removePendingProductEdit(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList('pending_product_edits') ?? [];
    current.removeWhere((item) => jsonDecode(item)['id'] == id);
    await prefs.setStringList('pending_product_edits', current);
  }
}

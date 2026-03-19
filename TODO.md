# TODO: Implementación Funcionalidades Pagos POS/Inventary

## Estado: En Progreso

### 1. [ ] Crear TODO.md ✅ COMPLETADO

### 2. [✅] Actualizar modelos Dart (lib/features/sales/domain/sale.dart)
   - ✅ toJson() completo para Sale y Payment

### 3. [✅] Backend Python (servidor.py)
   - ✅ POST /api/ventas ya guarda JSON metodos_pago + detalles
   - ✅ GET /api/ventas/pendientes (filtrar pendientes)

### 4. [✅] Providers (lib/features/sales/presentation/providers/)
   - ✅ pending_payments_provider.dart (fetch, process)

### 5. [✅] Nueva Pantalla (lib/features/sales/presentation/screens/)
   - ✅ pending_payments_screen.dart (lista + procesar pago)

### 6. [✅] Navegación (lib/main.dart)
   - ✅ Pending Payments en menú (índice 4)

### 7. [✅] POS Screen (pos_screen.dart)
   - ✅ Validación estricta suma pagos == total (ya existe)
   - ✅ Integrar procesar pendiente (cart ext + provider)

### 8. [✅] Reportes Cierre Caja
   - ✅ reports_provider.dart: desglose paymentsUSD/VES
   - ✅ reports_screen.dart: UI desglose bimonetario

### 9. [✅] Testing ✅ COMPLETADO
   - ✅ flutter pub get
   - Listo: python servidor.py
   - Listo: Test app (POS mixtos, pendientes, reportes desglosados)

---

**Próximo paso**: 2. Modelos Dart

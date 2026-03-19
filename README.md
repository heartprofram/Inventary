# 🛒 Sistema de Inventario y POS (Flutter + Google Sheets)

Un sistema de Punto de Venta (POS) y control de inventario construido con **Flutter**. Este proyecto utiliza **Google Sheets como base de datos gratuita en la nube** y cuenta con una arquitectura híbrida de código único (Single Codebase) que le permite ejecutarse de forma nativa en dispositivos Android y a través de un navegador Web de forma segura.

## ✨ Características Principales

* **Control de Inventario:** Creación, lectura y actualización de productos, control de stock y códigos de barras.
* **Punto de Venta (POS):** Carrito de compras, cálculo de totales en USD y Moneda Local (VES con tasa BCV automatizada), múltiples métodos de pago.
* **Cuentas por Cobrar:** Gestión de ventas a crédito y pagos parciales o totales.
* **Movimientos de Caja:** Registro de ingresos y egresos adicionales.
* **Reportes y Cierres (Reporte Z):** Generación y exportación de recibos y cierres de caja diarios en formato PDF.
* **Arquitectura Híbrida:**
  * **Android:** Conexión directa y segura a la API de Google Sheets (`googleapis_auth`).
  * **Web:** Conexión a través de un servidor proxy local en Python (`servidor.py`) usando `Dio` para evadir restricciones de CORS y evitar la exposición de llaves privadas en el navegador.

---

## 🚀 Requisitos Previos

* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión 3.10 o superior recomendada).
* [Python 3.x](https://www.python.org/downloads/) (Solo necesario para ejecutar la versión Web).
* Librerías de Python: `pip install google-auth google-auth-httplib2 google-api-python-client flask-cors`

---

## 🛠️ Configuración de la Base de Datos (Google Sheets)

La aplicación utiliza un documento de Google Sheets para almacenar toda la información.

1. Crea un nuevo documento en [Google Sheets](https://docs.google.com/spreadsheets/).
2. Copia el **ID de la hoja de cálculo** que aparece en la URL de tu navegador. 
   *(Ejemplo: `https://docs.google.com/spreadsheets/d/AQUI_ESTA_EL_ID/edit`)*
3. Abre el código del proyecto y pega este ID en dos lugares:
   * En `lib/core/constants/app_constants.dart` (`spreadSheetId`).
   * En `servidor.py` (`SPREADSHEET_ID = 'TU_ID_AQUI'`).
4. **Las pestañas (hojas) se crearán automáticamente:** Al iniciar el servidor Python por primera vez, este detectará si el documento está vacío y creará automáticamente las pestañas necesarias (`Productos`, `Ventas`, `Movimientos`, `DetalleVentas`) con sus respectivos encabezados.

---

## 🔑 Obtención de Credenciales (API Keys)

Para que la aplicación pueda leer y escribir en tu Google Sheet, necesitas una "Cuenta de Servicio" (Service Account) de Google Cloud.

### Paso 1: Habilitar la API
1. Ve a la [Consola de Google Cloud](https://console.cloud.google.com/).
2. Crea un **Nuevo Proyecto**.
3. En el menú lateral, ve a **API y Servicios** > **Biblioteca**.
4. Busca **"Google Sheets API"** y haz clic en **Habilitar**.

### Paso 2: Crear la Cuenta de Servicio
1. Ve a **API y Servicios** > **Credenciales**.
2. Haz clic en **+ CREAR CREDENCIALES** y selecciona **Cuenta de servicio**.
3. Ponle un nombre (ej. `pos-inventario`) y haz clic en "Crear y Continuar", luego en "Listo".
4. En la lista de Cuentas de servicio, verás un correo electrónico generado (ej. `pos-inventario@tu-proyecto.iam.gserviceaccount.com`). **Copia este correo.**

### Paso 3: Descargar la Llave JSON
1. Haz clic sobre el correo de la cuenta de servicio que acabas de crear.
2. Ve a la pestaña **Claves** (Keys).
3. Haz clic en **Agregar clave** > **Crear clave nueva**.
4. Selecciona el formato **JSON** y haz clic en "Crear". 
5. Se descargará un archivo en tu computadora. Renómbralo a **`credentials.json`**.
6. Mueve este archivo dentro de la carpeta `assets/` de tu proyecto Flutter.

### Paso 4: Dar acceso a la Hoja de Cálculo
1. Ve a tu documento de Google Sheets.
2. Haz clic en el botón **Compartir** (esquina superior derecha).
3. Pega el **correo de la cuenta de servicio** (el que copiaste en el Paso 2).
4. Otórgale permisos de **Editor** y haz clic en Enviar.

---

## 🛡️ Seguridad Importante (`.gitignore`)

El archivo `credentials.json` contiene llaves privadas que **NUNCA** deben ser subidas a repositorios públicos como GitHub.
Asegúrate de que tu archivo `.gitignore` incluya la siguiente línea antes de hacer un commit:

```text
# Credenciales privadas de Google
assets/credentials.json
```
(Se ha provisto un archivo `credentials.example.json` en el repositorio para ilustrar la estructura esperada de la llave).

---

## 💻 Ejecución del Proyecto

### Para Android (Nativo)
La versión móvil no requiere el servidor Python, se conecta directamente a Google Sheets.

1. Conecta tu dispositivo o inicia un emulador.
2. Ejecuta la aplicación:
   ```bash
   flutter run
   ```
3. Para compilar el instalador final:
   ```bash
   flutter build apk --release
   ```

### Para Web (Navegador)
Debido a las políticas de seguridad web (CORS), la versión web requiere el servidor proxy local.

1. Abre una terminal y enciende el servidor:
   ```bash
   python servidor.py
   ```
2. Abre otra terminal y ejecuta el cliente Flutter:
   ```bash
   flutter run -d chrome
   ```

---

## 📄 Licencia
Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.

Copyright (c) 2026 Edwin Medina

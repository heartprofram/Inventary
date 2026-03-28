<div align="center">
  <img src="Inventaryico.png" alt="Inventary Logo" width="150" height="150">
  <h1>Inventary & POS v1.9.3</h1>
  <p><em>Sistema Híbrido de Punto de Venta e Inventario (Flutter + Google Sheets + FastAPI)</em></p>
</div>

---

## 📖 Descripción del Proyecto
Un sistema de Punto de Venta (POS) y control de inventario de nivel de producción construido con **Flutter**. Este proyecto utiliza **Google Sheets como base de datos gratuita en la nube** y cuenta con una arquitectura híbrida avanzada (Single Codebase) que le permite ejecutarse de forma nativa e independiente en dispositivos Android, y a través de un navegador Web de forma segura y veloz.

---

## 🏗️ Arquitectura y Entornos (¿Cómo funciona?)

Este sistema está compuesto por tres pilares fundamentales que garantizan su escalabilidad y resistencia a fallos:

### 📱 1. Aplicación Android (APK Independiente)
Diseñada para el trabajo de campo y los cajeros. Funciona de manera **100% nativa e independiente** sin necesidad del servidor Python.
* **Modo Offline Real:** Se conecta directamente a la API de Google Sheets (`googleapis_auth`) y a DolarAPI. Si el internet falla, las operaciones se guardan en el dispositivo y se sincronizan silenciosamente al recuperar la conexión.

### 🌐 2. Aplicación Web (PWA)
Una interfaz rápida y accesible desde cualquier navegador, ideal para la gestión administrativa en computadoras de escritorio. 
* Trabaja en conjunto con el servidor Python local usando `Dio` para evadir las restricciones de seguridad web (CORS) y asegurar un flujo de datos asíncrono impecable.

### ⚙️ 3. Servidor Backend (Python + FastAPI)
El motor detrás de la versión Web. 
* Actúa como un puente seguro entre la aplicación en el navegador y Google Sheets. Centraliza las consultas, sirve los archivos estáticos de la web y procesa grandes volúmenes de datos rápidamente gracias a su naturaleza asíncrona.

---

## ✨ Características Principales

* 📦 **Control de Inventario:** Creación, lectura y actualización de productos, control de stock y escaneo de códigos de barras (IDs generados automáticamente).
* 🛒 **Punto de Venta Optimizado (POS):** Carrito de compras con **Tarjetas de pago rápido** (Efectivo USD/Bs, Pago Móvil, Punto, Fiado) para ventas en un solo toque. Cálculo de totales en USD y Moneda Local (VES con tasa BCV automatizada).
* 💳 **Cuentas por Cobrar Avanzadas:** Gestión de ventas a crédito, abonos y capacidad de registrar deudas manuales directamente desde el panel.
* 🔄 **Historial y Devoluciones:** Consulta detallada de ventas con opción de **editar ventas, intercambiar productos o procesar devoluciones** de forma intuitiva.
* 📄 **Reportes en PDF:** Exportación de facturas individuales estéticas y Reportes de Ventas y Cierres de Caja por períodos (Ayer, Semana, Mes, Global) con cálculos de rentabilidad.
* 📊 **Movimientos de Caja:** Registro de ingresos y egresos adicionales para un cuadre financiero exacto.

---

## 🚀 Requisitos Previos e Instalación

* **Flutter SDK:** ^3.19.0 o superior.
* **Python:** 3.9 o superior.

### 🐍 1. Preparar el Servidor Python
Para que el backend funcione y pueda servir la página web, instala las dependencias de FastAPI y Google:
```bash
pip install fastapi uvicorn pydantic google-auth google-auth-httplib2 google-api-python-client
```

### 📲 2. Compilar y Ejecutar en Android (APK)
Para generar el instalador móvil (que funcionará de forma independiente):

1. Descarga las dependencias de Flutter:
```bash
flutter pub get
```

2. Genera el instalador APK optimizado para producción:
```bash
flutter build apk --release
```
(El archivo resultante estará listo para instalar en `build/app/outputs/flutter-apk/app-release.apk`)

### 💻 3. Compilar y Ejecutar en Web
Para desplegar la aplicación en tu computadora de escritorio:

1. Compila los binarios de la aplicación Web:
```bash
flutter build web
```

2. Inicia el servidor Backend (el cual servirá los archivos compilados en el paso anterior):
```bash
python servidor.py
```
Tu navegador se abrirá automáticamente (o ingresa a `http://localhost:8081`).

---

## 🛠️ Configuración de la Base de Datos (Google Sheets)
La aplicación utiliza un documento de Google Sheets para almacenar toda la información.

1. Crea un nuevo documento vacío en **Google Sheets**.
2. Copia el **ID de la hoja de cálculo** que aparece en la URL de tu navegador. (Ejemplo: `https://docs.google.com/spreadsheets/d/AQUI_ESTA_EL_ID/edit`)
3. Pega este ID en el código del proyecto:
   - En `lib/core/constants/app_constants.dart` (variable `spreadSheetId`).
   - En `servidor.py` (variable `SPREADSHEET_ID`).

💡 **Nota:** Al iniciar el servidor Python por primera vez, detectará si el documento está vacío y creará automáticamente las pestañas necesarias (`Productos`, `Ventas`, `Movimientos`, `DetalleVentas`) con sus respectivos encabezados.

---

## 🔑 Obtención de Credenciales (API Keys)
Para que la app lea y escriba en tu Google Sheet de forma segura, necesitas una Cuenta de Servicio de Google Cloud.

**Paso 1: Habilitar la API**
1. Ve a la **Consola de Google Cloud**.
2. Crea un **Nuevo Proyecto**.
3. Ve a **API y Servicios > Biblioteca**, busca **"Google Sheets API"** y actívala.

**Paso 2: Crear la Cuenta de Servicio**
1. Ve a **API y Servicios > Credenciales**.
2. Haz clic en **+ CREAR CREDENCIALES** y selecciona **Cuenta de servicio**.
3. Ponle un nombre y finaliza.
4. Copia el **correo electrónico** generado (ej. `pos-inventario@tu-proyecto.iam.gserviceaccount.com`).

**Paso 3: Descargar la Llave JSON**
1. Haz clic sobre el correo de la cuenta de servicio creada.
2. En la pestaña **Claves (Keys)**, haz clic en **Agregar clave > Crear clave nueva** (formato JSON).
3. Se descargará un archivo. Renómbralo a **`credentials.json`** y muévelo a la carpeta **`assets/`** de este proyecto.

**Paso 4: Dar acceso a la Hoja de Cálculo**
1. Ve a tu documento de Google Sheets.
2. Haz clic en **Compartir** (esquina superior derecha).
3. Pega el **correo de la cuenta de servicio**, dale permisos de **Editor** y guarda.

---

## 🛡️ Seguridad Importante (`.gitignore`)
El archivo `credentials.json` contiene llaves privadas que **NUNCA** deben ser subidas a repositorios públicos de GitHub. El archivo `.gitignore` de este proyecto ya está configurado para ignorarlo:

```plaintext
# Credenciales privadas de Google
assets/credentials.json
```
(Se incluye un archivo `credentials.example.json` en el repositorio para ilustrar la estructura de la llave).

---

## 📄 Licencia
Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.

**Copyright (c) 2026 Edwin Medina**  
**GitHub:** [@Heartprofram](https://github.com/heartprofram)

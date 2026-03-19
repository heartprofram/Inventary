
# Inventario & POS - Sistema de Inventario y Punto de Venta

## Descripción General

Este proyecto es un sistema completo de Punto de Venta (POS) e inventario diseñado para ser utilizado tanto en dispositivos Android como en la web. La aplicación está construida con Flutter y utiliza un backend de Python para la versión web, con Google Sheets como base de datos.

## Características Principales

- **Gestión de Inventario:** Permite agregar, editar y eliminar productos, así como controlar el stock en tiempo real.
- **Punto de Venta (POS):** Facilita la creación de ventas de forma rápida y sencilla.
- **Historial de Ventas:** Mantiene un registro detallado de todas las ventas realizadas, permitiendo filtrar y buscar por fecha.
- **Movimientos de Inventario:** Registra todos los movimientos de entrada y salida de productos, proporcionando un seguimiento completo.
- **Cierre de Caja:** Genera reportes de cierre de caja para conciliar las ventas del día.
- **Sincronización con Google Sheets:** Utiliza una hoja de cálculo de Google como base de datos, lo que permite una gestión de datos centralizada y accesible.
- **Multiplataforma:** Funciona tanto en Android (a través de un APK) como en la web (a través de un navegador).

## Arquitectura del Software

El proyecto sigue una arquitectura de software limpia y modular, separando las responsabilidades en diferentes capas y módulos.

- **Capa de Presentación (Flutter):**
  - **Framework:** Flutter
  - **Gestión de Estado:** `flutter_riverpod` para un manejo de estado reactivo y eficiente.
  - **UI:** Widgets de Material Design para una interfaz de usuario moderna y atractiva.

- **Capa de Lógica de Negocio (Backend - Python):**
  - **Servidor:** `servidor.py` actúa como un servidor HTTP que sirve la aplicación web de Flutter.
  - **API Proxy:** El backend funciona como un proxy que se comunica con la API de Google Sheets, proporcionando una capa de seguridad y abstracción.
  - **Comunicación:** La aplicación Flutter se comunica con el backend a través de una API RESTful.

- **Capa de Datos (Google Sheets):**
  - **Base de Datos:** Una hoja de cálculo de Google Sheets se utiliza como base de datos para almacenar productos, ventas y movimientos.
  - **Interacción:** El backend de Python interactúa con la hoja de cálculo utilizando la API de Google Sheets.

## Estructura de Archivos

El proyecto está organizado en una estructura de carpetas clara y concisa:

```
├── android/          # Código nativo de Android
├── assets/           # Archivos de credenciales y otros recursos
├── build/            # Archivos de compilación
├── lib/
│   ├── core/         # Funcionalidades compartidas
│   │   ├── constants/
│   │   ├── error/
│   │   ├── network/
│   │   ├── providers/
│   │   ├── services/ # Servicios (ej. Google API Service)
│   │   └── utils/
│   ├── features/     # Módulos de la aplicación
│   │   ├── inventory/
│   │   ├── reports/
│   │   ├── sales/
│   │   └── settings/
│   └── main.dart     # Punto de entrada de la aplicación
├── servidor.py       # Backend de Python para la versión web
├── pubspec.yaml      # Dependencias y configuración del proyecto
└── README.md         # Este archivo
```

## Módulos de la Aplicación

La aplicación está dividida en los siguientes módulos:

- **Inventario (`/lib/features/inventory`):**
  - **`presentation/screens/inventory_screen.dart`:** Pantalla para gestionar el inventario de productos.

- **Ventas (`/lib/features/sales`):**
  - **`presentation/screens/pos_screen.dart`:** Pantalla principal del Punto de Venta.
  - **`presentation/screens/sales_history_screen.dart`:** Pantalla para ver el historial de ventas.

- **Reportes (`/lib/features/reports`):**
  - **`presentation/screens/reports_screen.dart`:** Pantalla para generar reportes.
  - **`presentation/screens/movements_screen.dart`:** Pantalla para ver los movimientos de inventario.

- **Configuración (`/lib/features/settings`):**
  - **`presentation/screens/settings_screen.dart`:** Pantalla para configurar la aplicación.

## Backend (`servidor.py`)

El backend de Python es responsable de:

- Servir la aplicación web de Flutter.
- Actuar como un proxy seguro para la API de Google Sheets.
- Exponer una API RESTful para que la aplicación Flutter pueda interactuar con los datos.
- Obtener la tasa de cambio del dólar desde una API externa para la versión web.

### Endpoints de la API

- `GET /api/productos`: Obtiene la lista de productos.
- `POST /api/productos`: Agrega un nuevo producto.
- `PUT /api/productos/stock`: Actualiza el stock de un producto.
- `PUT /api/productos/update`: Actualiza los datos de un producto.
- `GET /api/ventas`: Obtiene el historial de ventas.
- `POST /api/ventas`: Agrega una nueva venta.
- `GET /api/movimientos`: Obtiene los movimientos de inventario.
- `POST /api/movimientos`: Agrega un nuevo movimiento.
- `GET /api/detalle_ventas`: Obtiene los detalles de las ventas.
- `POST /api/detalle_ventas`: Agrega detalles de una venta.
- `GET /api/tasa`: Obtiene la tasa de cambio del dólar.

## Cómo Ejecutar la Aplicación

### Versión Web

1. **Instalar dependencias de Python:**
   ```bash
   pip install google-auth google-auth-httplib2 google-api-python-client
   ```
2. **Construir la aplicación web de Flutter:**
   ```bash
   flutter build web
   ```
3. **Ejecutar el servidor de Python:**
   ```bash
   python servidor.py
   ```
4. **Abrir la aplicación en el navegador:**
   [http://localhost:8081](http://localhost:8081)

### Versión Android

1. **Conectar un dispositivo Android o iniciar un emulador.**
2. **Ejecutar la aplicación:**
   ```bash
   flutter run
   ```
   También se puede generar un APK para instalar en el dispositivo:
   ```bash
   flutter build apk
   ```

## Dependencias del Proyecto

### Flutter (`pubspec.yaml`)
- `flutter_riverpod`: Gestión de estado.
- `http`, `dio`: Peticiones HTTP.
- `googleapis`, `googleapis_auth`, `google_sign_in`: Integración con Google API.
- `pdf`, `printing`: Generación e impresión de PDFs.
- `shared_preferences`: Almacenamiento local simple.
- `url_launcher`: Abrir URLs.
- `open_filex`: Abrir archivos.
- `intl`: Internacionalización.

### Python (`servidor.py`)
- `google-auth`
- `google-auth-httplib2`
- `google-api-python-client`

**Nota:** Este `README.md` ha sido generado automáticamente y resume la estructura y funcionalidades del proyecto.

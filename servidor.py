"""
Servidor Proxy para Sistema POS + Inventario
============================================
Sirve la app Flutter Web Y hace de puente seguro con Google Sheets API.
Corre con: python servidor.py
Luego abre: http://localhost:8080
"""
import json
import os
import sys
import threading
import urllib.request
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

# Librerías de Google
try:
    import google.auth
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
except ImportError:
    print("\n[ERROR] Faltan librerías de Google. Instálalas con:")
    print("  pip install google-auth google-auth-httplib2 google-api-python-client\n")
    exit(1)

# ─── CONFIGURACIÓN ────────────────────────────────────────────
SPREADSHEET_ID = '1PSLrL9OFdXh-HCwxI1JXdTFM8zL6vMwOx0Yj7rUQ10Y'

def resource_path(relative_path):
    """ Obtiene la ruta absoluta al recurso, funciona para dev y para PyInstaller """
    try:
        # PyInstaller crea una carpeta temporal y guarda la ruta en _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

CREDENTIALS_FILE = resource_path(os.path.join('assets', 'credentials.json'))
WEB_DIR = resource_path(os.path.join('build', 'web'))
PORT = 8081
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']
# ──────────────────────────────────────────────────────────────

# Inicializar cliente de Google Sheets
creds = service_account.Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=SCOPES)
sheets_service = build('sheets', 'v4', credentials=creds, cache_discovery=False)

def sheets_get(range_name):
    result = sheets_service.spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID, range=range_name
    ).execute()
    return result.get('values', [])

def sheets_append(range_name, values):
    sheets_service.spreadsheets().values().append(
        spreadsheetId=SPREADSHEET_ID,
        range=range_name,
        valueInputOption='USER_ENTERED',
        body={'values': values}
    ).execute()

def sheets_update(range_name, values):
    sheets_service.spreadsheets().values().update(
        spreadsheetId=SPREADSHEET_ID,
        range=range_name,
        valueInputOption='USER_ENTERED',
        body={'values': values}
    ).execute()

class PosHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def _json_response(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', len(body))
        
        # Evitar caché en el navegador / app cliente para estas repsuestas API
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        
        self._cors()
        self.end_headers()
        self.wfile.write(body)
        print(f"   [API] {self.command} {self.path} -> {status}")

    def _error(self, msg, status=500):
        self._json_response({'error': msg}, status)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/tasa':
            try:
                import time
                timestamp = int(time.time() * 1000)
                # Proxy a DolarApi para evitar CORS y obtener tasa BCV confiable
                url = f'https://ve.dolarapi.com/v1/dolares/oficial?t={timestamp}'
                
                req = urllib.request.Request(url, headers={
                    'User-Agent': 'Mozilla/5.0',
                    'Cache-Control': 'no-cache'
                })
                with urllib.request.urlopen(req, timeout=10) as response:
                    raw_data = json.loads(response.read().decode())
                    
                    # Extraer precio de la estructura de dolarapi
                    price = 0.0
                    try:
                        price = float(raw_data.get('promedio', 0.0))
                    except (ValueError, TypeError):
                        pass
                        
                    # Retornar en el mismo formato que esperaba la app {"promedio": x}
                    self._json_response({"promedio": price})
            except Exception as e:
                self._error(str(e))

        elif path == '/api/productos':
            try:
                rows = sheets_get('Productos!A2:G')
                self._json_response(rows)
            except Exception as e:
                self._error(str(e))

        elif path == '/api/ventas':
            try:
                rows = sheets_get('Ventas!A2:H')
                self._json_response(rows)
            except Exception as e:
                self._error(str(e))

        elif path == '/api/ventas/pendientes':
            try:
                all_ventas = sheets_get('Ventas!A2:H')
                detalle_ventas = sheets_get('DetalleVentas!A2:F')
                
                pendientes = []
                for venta_row in all_ventas:
                    if len(venta_row) >= 7 and 'pendiente' in str(venta_row[5]).lower():
                        # Encontrar detalles de esta venta
                        venta_details = [det for det in detalle_ventas if det and len(det) > 0 and det[0] == venta_row[0]]
                        
                        pendientes.append({
                            'id_venta': venta_row[0],
                            'fecha': venta_row[1],
                            'total_usd': float(venta_row[2]) if len(venta_row) > 2 and venta_row[2] else 0.0,
                            'deudor': venta_row[7] if len(venta_row) > 7 else '',
                            'detalles_productos': venta_details,
                            'metodos_pago': json.loads(venta_row[5]) if len(venta_row) > 5 and venta_row[5] else []
                        })
                
                self._json_response(pendientes)
            except Exception as e:
                self._error(str(e))

        elif path == '/api/movimientos':
            try:
                rows = sheets_get('Movimientos!A2:F')
                self._json_response(rows)
            except Exception as e:
                self._error(str(e))

        elif path == '/api/detalle_ventas':
            try:
                rows = sheets_get('DetalleVentas!A2:F')
                self._json_response(rows)
            except Exception as e:
                self._error(str(e))

        else:
            # Servir la app Flutter Web
            super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(length)) if length > 0 else {}

        if path == '/api/productos':
            try:
                row = body.get('row', [])
                sheets_append('Productos!A:G', [row])
                self._json_response({'ok': True})
            except Exception as e:
                self._error(str(e))

        elif path == '/api/ventas':
            try:
                venta_data = body.get('venta', {})
                detalles_data = body.get('detalles', [])

                # Procesar la venta principal
                venta_row = [
                    venta_data.get('id_venta'),
                    venta_data.get('fecha'),
                    venta_data.get('total_usd'),
                    venta_data.get('total_ves'),
                    venta_data.get('tasa_cambio'),
                    json.dumps(venta_data.get('metodos_pago')), # Guardar como JSON string
                    venta_data.get('pdf_url', ''),
                    venta_data.get('detalles', '') # Para nombre del deudor
                ]
                sheets_append('Ventas!A:H', [venta_row])

                # Procesar los detalles de la venta
                for detalle in detalles_data:
                    detalle_row = [
                        venta_data.get('id_venta'),
                        detalle.get('id_producto'),
                        detalle.get('nombre_producto'),
                        detalle.get('cantidad'),
                        detalle.get('precio_unitario_usd'),
                        detalle.get('subtotal_usd')
                    ]
                    sheets_append('DetalleVentas!A:F', [detalle_row])
                
                self._json_response({'ok': True, 'id_venta': venta_data.get('id_venta')})

            except Exception as e:
                self._error(str(e))

        elif path == '/api/movimientos':
            try:
                row = body.get('row', [])
                sheets_append('Movimientos!A:F', [row])
                self._json_response({'ok': True})
            except Exception as e:
                self._error(str(e))

        else:
            self._error('Ruta no encontrada', 404)

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(length)) if length > 0 else {}

        if path == '/api/productos/stock':
            try:
                range_name = body.get('range')
                value = body.get('value')
                sheets_update(range_name, [[value]])
                self._json_response({'ok': True})
            except Exception as e:
                self._error(str(e))

        elif path == '/api/productos/update':
            try:
                range_name = body.get('range')
                row = body.get('row', [])
                sheets_update(range_name, [row])
                self._json_response({'ok': True})
            except Exception as e:
                self._error(str(e))

        elif path == '/api/ventas/update_status':
            try:
                sale_id = body.get('id_venta')
                new_payment_methods = body.get('metodos_pago')
                
                # 1. Encontrar la fila que coincide con el ID de venta
                ventas = sheets_get('Ventas!A2:H')
                row_index = -1
                for i, row in enumerate(ventas):
                    if row and row[0] == sale_id:
                        row_index = i + 2  # +2 porque el índice es base 0 y los datos empiezan en la fila 2
                        break
                
                if row_index == -1:
                    return self._error('ID de venta no encontrado', 404)

                # 2. Actualizar el método de pago (columna G) y limpiar detalles (columna H)
                range_to_update = f'Ventas!F{row_index}:H{row_index}'
                values_to_update = [[json.dumps(new_payment_methods), '', '']] # Limpiar URL y Detalles
                sheets_update(range_to_update, values_to_update)
                
                self._json_response({'ok': True, 'message': f'Venta {sale_id} actualizada.'})

            except Exception as e:
                self._error(str(e))

        else:
            self._error('Ruta no encontrada', 404)

    def log_message(self, format, *args):
        # Opcional: silenciar logs de recursos estáticos si se desea
        # if '/api' in args[0] if args else False:
        #     super().log_message(format, *args)
        super().log_message(format, *args)


if __name__ == '__main__':
    print(f"\nAutenticando con Google Sheets...")
    try:
        # Verificar que el spreadsheet existe y listar sus pestañas
        meta = sheets_service.spreadsheets().get(spreadsheetId=SPREADSHEET_ID).execute()
        sheet_titles = [s['properties']['title'] for s in meta.get('sheets', [])]
        print(f"Conexion exitosa! Hojas encontradas: {sheet_titles}")

        # Crear las pestañas si no existen
        needed = {'Productos', 'Ventas', 'Movimientos', 'DetalleVentas'}
        missing = needed - set(sheet_titles)
        if missing:
            print(f"Pestanas faltantes: {missing}. Creandolas automaticamente...")
            requests = [
                {'addSheet': {'properties': {'title': name}}}
                for name in missing
            ]
            sheets_service.spreadsheets().batchUpdate(
                spreadsheetId=SPREADSHEET_ID,
                body={'requests': requests}
            ).execute()
            print(f"Pestanas creadas: {missing}")

            # Agregar encabezados a Productos si es nueva
            if 'Productos' in missing:
                sheets_service.spreadsheets().values().update(
                    spreadsheetId=SPREADSHEET_ID,
                    range='Productos!A1:G1',
                    valueInputOption='USER_ENTERED',
                    body={'values': [['ID', 'Nombre', 'Descripción', 'Precio Costo USD', 'Precio Venta USD', 'Stock', 'Código Barras']]}
                ).execute()
            if 'Ventas' in missing:
                sheets_service.spreadsheets().values().update(
                    spreadsheetId=SPREADSHEET_ID,
                    range='Ventas!A1:H1',
                    valueInputOption='USER_ENTERED',
                    body={'values': [['ID Venta', 'Fecha', 'Total USD', 'Total VES', 'Tasa Cambio', 'Metodos de Pago', 'PDF', 'Detalles']]}
                ).execute()
            if 'Movimientos' in missing:
                sheets_service.spreadsheets().values().update(
                    spreadsheetId=SPREADSHEET_ID,
                    range='Movimientos!A1:F1',
                    valueInputOption='USER_ENTERED',
                    body={'values': [['ID Movimiento', 'Fecha', 'Tipo (Ingreso/Egreso)', 'Concepto', 'Monto USD', 'Monto VES']]}
                ).execute()
            if 'DetalleVentas' in missing:
                sheets_service.spreadsheets().values().update(
                    spreadsheetId=SPREADSHEET_ID,
                    range='DetalleVentas!A1:F1',
                    valueInputOption='USER_ENTERED',
                    body={'values': [['ID Venta', 'ID Producto', 'Nombre Producto', 'Cantidad', 'Precio Unitario USD', 'Subtotal USD']]}
                ).execute()

    except Exception as e:
        print(f"Error al conectar con Google Sheets: {e}")
        print("Verifica que el credentials.json sea correcto y la hoja esté compartida.")
        exit(1)

    def open_browser():
        webbrowser.open(f"http://localhost:{PORT}")

    print(f"Servidor corriendo en http://localhost:{PORT}")
    print(f"Hoja: {SPREADSHEET_ID}")
    print(f"App desde: {WEB_DIR}")
    print(f"   Presiona Ctrl+C para detener.\n")

    # Abrir el navegador automáticamente después de 2 segundos para dar tiempo al inicio
    threading.Timer(2.0, open_browser).start()

    print(f"Servidor multihilo listo. Escuchando peticiones...\n")
    server = ThreadingHTTPServer(('0.0.0.0', PORT), PosHandler)
    server.serve_forever()

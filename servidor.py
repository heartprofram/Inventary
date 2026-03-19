"""
Servidor Proxy para Sistema POS + Inventario
============================================
Sirve la app Flutter Web Y hace de puente seguro con Google Sheets API.
Corre con: python servidor.py
Luego abre: http://localhost:8081
"""
import json
import os
import sys
import threading
import urllib.request
import webbrowser
from http.server import HTTPServer, SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

try:
    import google.auth
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
except ImportError:
    print("\n[ERROR] Faltan librerías de Google. Instálalas con:")
    print("  pip install google-auth google-auth-httplib2 google-api-python-client\n")
    exit(1)

SPREADSHEET_ID = '1PSLrL9OFdXh-HCwxI1JXdTFM8zL6vMwOx0Yj7rUQ10Y'

def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

CREDENTIALS_FILE = resource_path(os.path.join('assets', 'credentials.json'))
WEB_DIR = resource_path(os.path.join('build', 'web'))
PORT = 8081
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

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
    extensions_map = SimpleHTTPRequestHandler.extensions_map.copy()
    extensions_map.update({
        '.js': 'application/javascript',
        '.wasm': 'application/wasm',
        '.json': 'application/json',
        '.html': 'text/html',
        '.css': 'text/css'
    })

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def _json_response(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        self.end_headers()
        self.wfile.write(body)
        print(f"   [API] {self.command} {self.path} -> {status}")

    def _error(self, msg, status=500):
        self._json_response({'error': msg}, status)

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/tasa':
            try:
                import time
                timestamp = int(time.time() * 1000)
                url = f'https://ve.dolarapi.com/v1/dolares/oficial?t={timestamp}'
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                with urllib.request.urlopen(req, timeout=10) as response:
                    raw_data = json.loads(response.read().decode())
                    price = float(raw_data.get('promedio', 0.0))
                    self._json_response({"promedio": price})
            except Exception as e:
                self._error(str(e))

        elif path == '/api/productos':
            self._json_response(sheets_get('Productos!A2:G'))

        elif path == '/api/ventas':
            self._json_response(sheets_get('Ventas!A2:H'))
            
        elif path == '/api/detalle_ventas':
            self._json_response(sheets_get('DetalleVentas!A2:F'))

        elif path == '/api/ventas/pendientes':
            try:
                all_ventas = sheets_get('Ventas!A2:H')
                detalle_ventas = sheets_get('DetalleVentas!A2:F')
                pendientes = []
                for venta_row in all_ventas:
                    if len(venta_row) >= 7 and 'pendiente' in str(venta_row[5]).lower():
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
            self._json_response(sheets_get('Movimientos!A2:F'))

        else:
            super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(length)) if length > 0 else {}

        if path == '/api/productos':
            sheets_append('Productos!A:G', [body.get('row', [])])
            self._json_response({'ok': True})

        elif path == '/api/ventas':
            try:
                venta_data = body.get('venta', {})
                detalles_data = body.get('detalles', [])

                venta_row = [
                    venta_data.get('id_venta'),
                    venta_data.get('fecha'),
                    venta_data.get('total_usd'),
                    venta_data.get('total_ves'),
                    venta_data.get('tasa_cambio'),
                    json.dumps(venta_data.get('metodos_pago')), 
                    venta_data.get('pdf_url', ''),
                    venta_data.get('detalles', '') 
                ]
                sheets_append('Ventas!A:H', [venta_row])

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
            sheets_append('Movimientos!A:F', [body.get('row', [])])
            self._json_response({'ok': True})
        else:
            self._error('Ruta no encontrada', 404)

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(length)) if length > 0 else {}

        if path == '/api/productos/stock' or path == '/api/productos/update':
            try:
                range_name = body.get('range')
                value = body.get('value') if path == '/api/productos/stock' else body.get('row', [])
                sheets_update(range_name, [[value]] if path == '/api/productos/stock' else [value])
                self._json_response({'ok': True})
            except Exception as e:
                self._error(str(e))

        elif path == '/api/ventas/update_status':
            try:
                sale_id = body.get('id_venta')
                new_payment_methods = body.get('metodos_pago')
                
                ventas = sheets_get('Ventas!A2:H')
                row_index = -1
                for i, row in enumerate(ventas):
                    if row and row[0] == sale_id:
                        row_index = i + 2  
                        break
                
                if row_index == -1:
                    return self._error('ID de venta no encontrado', 404)

                range_to_update = f'Ventas!F{row_index}:H{row_index}'
                sheets_update(range_to_update, [[json.dumps(new_payment_methods), '', '']])
                
                self._json_response({'ok': True, 'message': f'Venta {sale_id} actualizada.'})
            except Exception as e:
                self._error(str(e))
        else:
            self._error('Ruta no encontrada', 404)

    # NUEVO METODO: Capacidad de eliminar (DELETE)
    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path.startswith('/api/ventas/'):
            sale_id = path.split('/')[-1]
            try:
                # Obtener IDs de las hojas
                meta = sheets_service.spreadsheets().get(spreadsheetId=SPREADSHEET_ID).execute()
                sheet_ids = {s['properties']['title']: s['properties']['sheetId'] for s in meta.get('sheets', [])}
                
                ventas = sheets_get('Ventas!A:H')
                row_index = -1
                for i, row in enumerate(ventas):
                    if row and row[0] == sale_id:
                        row_index = i
                        break
                
                detalles = sheets_get('DetalleVentas!A:F')
                detail_indices = [i for i, row in enumerate(detalles) if row and row[0] == sale_id]
                
                requests = []
                
                # Preparar requests de abajo hacia arriba para no dañar los índices
                for idx in sorted(detail_indices, reverse=True):
                    requests.append({
                        'deleteDimension': {
                            'range': {
                                'sheetId': sheet_ids.get('DetalleVentas', 0),
                                'dimension': 'ROWS',
                                'startIndex': idx,
                                'endIndex': idx + 1
                            }
                        }
                    })
                
                if row_index != -1:
                    requests.append({
                        'deleteDimension': {
                            'range': {
                                'sheetId': sheet_ids.get('Ventas', 0),
                                'dimension': 'ROWS',
                                'startIndex': row_index,
                                'endIndex': row_index + 1
                            }
                        }
                    })
                
                if requests:
                    sheets_service.spreadsheets().batchUpdate(
                        spreadsheetId=SPREADSHEET_ID,
                        body={'requests': requests}
                    ).execute()
                    
                self._json_response({'ok': True})
            except Exception as e:
                self._error(str(e))
        else:
            self._error('Ruta no encontrada', 404)

    def log_message(self, format, *args):
        super().log_message(format, *args)


if __name__ == '__main__':
    url = f"http://localhost:{PORT}"
    print(f"\n[SERVIDOR] Iniciando Sistema POS...")
    print(f"[SERVIDOR] URL: {url}")
    print(f"[SERVIDOR] Carpeta Web: {WEB_DIR}")
    print(f"\nEscuchando peticiones...\n")
    
    # Abrir el navegador predeterminado automáticamente tras un pequeño delay
    threading.Timer(1.5, lambda: webbrowser.open(url)).start()
    
    server = ThreadingHTTPServer(('0.0.0.0', PORT), PosHandler)
    server.serve_forever()
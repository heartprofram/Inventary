"""
Servidor Proxy para Sistema POS + Inventario (Migrado a FastAPI)
============================================================
Sirve la app Flutter Web Y hace de puente seguro con Google Sheets API.
Configurado para manejo asíncrono y robusto.

Requisitos:
pip install fastapi uvicorn google-auth google-auth-httplib2 google-api-python-client

Ejecutar con: python servidor.py
"""

import json
import os
import sys
import logging
import time
import urllib.request
import webbrowser
import asyncio
from typing import List, Optional, Any
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from contextlib import asynccontextmanager
import uvicorn

try:
    import google.auth
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
except ImportError:
    print("\n[ERROR] Faltan librerías de Google. Instálalas con:")
    print("  pip install google-auth google-auth-httplib2 google-api-python-client\n")
    exit(1)

# Configuración de Google Sheets
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

# Inicialización de credenciales y servicio
try:
    creds = service_account.Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=SCOPES)
except Exception as e:
    print(f"\n[ERROR] No se pudieron cargar las credenciales: {e}")
    print(f"Asegúrate de que {CREDENTIALS_FILE} existe y es válido.")
    sys.exit(1)
sheets_service = build('sheets', 'v4', credentials=creds, cache_discovery=False)

# --- Modelos de Pydantic ---

class RowData(BaseModel):
    row: list

class VentaVenta(BaseModel):
    id_venta: str
    fecha: str
    total_usd: float
    total_ves: float
    tasa_cambio: float
    metodos_pago: list
    pdf_url: Optional[str] = ""
    detalles: Optional[str] = ""

class VentaDetalle(BaseModel):
    id_producto: str
    nombre_producto: str
    cantidad: float
    precio_unitario_usd: float
    subtotal_usd: float

class VentaRequest(BaseModel):
    venta: VentaVenta
    detalles: List[VentaDetalle]

class UpdateProduct(BaseModel):
    range: str
    value: Optional[Any] = None
    row: Optional[list] = None

class UpdateStatusRequest(BaseModel):
    id_venta: str
    metodos_pago: list

# --- Funciones Auxiliares para Google Sheets (Síncronas para run_in_executor) ---

def _sheets_get(range_name):
    result = sheets_service.spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID, range=range_name
    ).execute()
    return result.get('values', [])

def _sheets_append(range_name, values):
    sheets_service.spreadsheets().values().append(
        spreadsheetId=SPREADSHEET_ID,
        range=range_name,
        valueInputOption='USER_ENTERED',
        body={'values': values}
    ).execute()

def _sheets_update(range_name, values):
    sheets_service.spreadsheets().values().update(
        spreadsheetId=SPREADSHEET_ID,
        range=range_name,
        valueInputOption='USER_ENTERED',
        body={'values': values}
    ).execute()

def _sheets_batch_update(body):
    sheets_service.spreadsheets().batchUpdate(
        spreadsheetId=SPREADSHEET_ID,
        body=body
    ).execute()

def _sheets_get_meta():
    return sheets_service.spreadsheets().get(spreadsheetId=SPREADSHEET_ID).execute()

# Envoltura asíncrona para llamadas bloqueantes
async def run_async(func, *args):
    return await asyncio.to_thread(func, *args)

# --- Lifespan de la Aplicación ---

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Abrir navegador tras 1.5 seg
    url = f"http://localhost:{PORT}"
    print(f"\n[SERVIDOR FASTAPI] Iniciando Sistema POS...")
    print(f"[SERVIDOR FASTAPI] URL: {url}")
    print(f"[SERVIDOR FASTAPI] Carpeta Web: {WEB_DIR}")
    
    def open_browser():
        time.sleep(1.5)
        webbrowser.open(url)
    
    import threading
    threading.Thread(target=open_browser, daemon=True).start()
    
    yield
    # Shutdown: No se requiere acción adicional

# --- Aplicación FastAPI ---

app = FastAPI(title="POS Inventory API", lifespan=lifespan)

# Configuración de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Endpoints ---

@app.get("/api/tasa")
async def get_tasa():
    try:
        timestamp = int(time.time() * 1000)
        url = f'https://ve.dolarapi.com/v1/dolares/oficial?t={timestamp}'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        
        # urllib es bloqueante, lo corremos en albacea
        def fetch():
            with urllib.request.urlopen(req, timeout=10) as response:
                return json.loads(response.read().decode())
        
        raw_data = await run_async(fetch)
        price = float(raw_data.get('promedio', 0.0))
        return {"promedio": price}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/productos")
async def get_productos():
    try:
        return await run_async(_sheets_get, 'Productos!A2:G')
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/ventas")
async def get_ventas():
    try:
        return await run_async(_sheets_get, 'Ventas!A2:H')
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/detalle_ventas")
async def get_detalle_ventas():
    try:
        return await run_async(_sheets_get, 'DetalleVentas!A2:F')
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/ventas/pendientes")
async def get_ventas_pendientes():
    try:
        all_ventas = await run_async(_sheets_get, 'Ventas!A2:H')
        detalle_ventas = await run_async(_sheets_get, 'DetalleVentas!A2:F')
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
        return pendientes
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/movimientos")
async def get_movimientos():
    try:
        return await run_async(_sheets_get, 'Movimientos!A2:F')
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/productos")
async def post_productos(data: RowData):
    try:
        await run_async(_sheets_append, 'Productos!A:G', [data.row])
        return {'ok': True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/ventas")
async def post_ventas(data: VentaRequest):
    try:
        venta_row = [
            data.venta.id_venta,
            data.venta.fecha,
            data.venta.total_usd,
            data.venta.total_ves,
            data.venta.tasa_cambio,
            data.venta.pdf_url,
            json.dumps(data.venta.metodos_pago),
            data.venta.detalles
        ]
        await run_async(_sheets_append, 'Ventas!A:H', [venta_row])

        for detalle in data.detalles:
            detalle_row = [
                data.venta.id_venta,
                detalle.id_producto,
                detalle.nombre_producto,
                detalle.cantidad,
                detalle.precio_unitario_usd,
                detalle.subtotal_usd
            ]
            await run_async(_sheets_append, 'DetalleVentas!A:F', [detalle_row])
        
        return {'ok': True, 'id_venta': data.venta.id_venta}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/movimientos")
async def post_movimientos(data: RowData):
    try:
        await run_async(_sheets_append, 'Movimientos!A:F', [data.row])
        return {'ok': True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/productos/stock")
async def put_productos_stock(data: UpdateProduct):
    try:
        await run_async(_sheets_update, data.range, [[data.value]])
        return {'ok': True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/productos/update")
async def put_productos_update(data: UpdateProduct):
    try:
        await run_async(_sheets_update, data.range, [data.row])
        return {'ok': True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/ventas/update_status")
async def update_venta_status(data: UpdateStatusRequest):
    try:
        ventas = await run_async(_sheets_get, 'Ventas!A2:H')
        row_index = -1
        for i, row in enumerate(ventas):
            if row and row[0] == data.id_venta:
                row_index = i + 2  
                break
        
        if row_index == -1:
            raise HTTPException(status_code=404, detail="ID de venta no encontrado")

        range_to_update = f'Ventas!G{row_index}'
        await run_async(_sheets_update, range_to_update, [[json.dumps(data.metodos_pago)]])
        
        return {'ok': True, 'message': f'Venta {data.id_venta} actualizada.'}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/ventas/{sale_id}")
async def delete_venta(sale_id: str):
    try:
        meta = await run_async(_sheets_get_meta)
        sheet_ids = {s['properties']['title']: s['properties']['sheetId'] for s in meta.get('sheets', [])}
        
        ventas = await run_async(_sheets_get, 'Ventas!A:H')
        row_index = -1
        for i, row in enumerate(ventas):
            if row and row[0] == sale_id:
                row_index = i # Índice base 0
                break
        
        detalles = await run_async(_sheets_get, 'DetalleVentas!A:G')
        detail_indices = [i for i, row in enumerate(detalles) if row and row[0] == sale_id]
        
        requests = []
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
            await run_async(_sheets_batch_update, {'requests': requests})
            
        return {'ok': True}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Servir archivos estáticos del build de Flutter Web
if os.path.exists(WEB_DIR):
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="static")

if __name__ == '__main__':
    uvicorn.run(app, host="0.0.0.0", port=PORT)
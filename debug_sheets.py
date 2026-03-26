import asyncio
import sys
import os

# Agregamos la ruta del sistema para poder importar servidor.py
sys.path.append(os.getcwd())

import servidor

async def main():
    try:
        print("Obteniendo registros de Ventas...")
        rows = await servidor.run_async(servidor._sheets_get, 'Ventas!A2:H')
        print(f"Total rows: {len(rows)}")
        last_rows = rows[-5:]
        for row in last_rows:
            print("ROW:")
            print(f"  Longitud: {len(row)}")
            for i, val in enumerate(row):
                print(f"  Columna {i}: {val}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    asyncio.run(main())

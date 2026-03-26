import asyncio
import sys
import os

sys.path.append(os.getcwd())
import servidor

async def main():
    try:
        rows = await servidor.run_async(servidor._sheets_get, 'Ventas!A1:H1')
        print(f"Headers: {rows[0]}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    asyncio.run(main())

import asyncio
import sys
import os

sys.path.append(os.getcwd())
import servidor

async def main():
    try:
        rows = await servidor.run_async(servidor._sheets_get, 'Ventas!A2:H')
        print(f"Total: {len(rows)}")
        for i, row in enumerate(rows[-3:]):
            print(f"--- Row {i} ---")
            print(f"Length: {len(row)}")
            if len(row) > 7:
                print(f"Col H (7): {row[7]}")
            else:
                print("No Col H!")
            pIndex = -1
            for j in range(5, len(row)):
                val = str(row[j]).strip()
                if val.startswith('[') and val.endswith(']'):
                    pIndex = j
                    break
            print(f"pIndex: {pIndex}")
            if pIndex != -1:
                name = row[pIndex + 1] if len(row) > pIndex + 1 else None
                print(f"Name using pIndex: {name}")
            else:
                name = row[7] if len(row) > 7 else None
                print(f"Name using fallback: {name}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == '__main__':
    asyncio.run(main())

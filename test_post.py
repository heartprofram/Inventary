import requests
import json
import time

url = "http://localhost:8081/api/ventas"

data = {
    "venta": {
        "id_venta": f"TEST-{int(time.time())}",
        "fecha": "2026-03-26T12:00:00Z",
        "total_usd": 15.0,
        "total_ves": 540.0,
        "tasa_cambio": 36.0,
        "metodos_pago": [{"method": "pendiente", "amount": 15.0}],
        "pdf_url": "",
        "detalles": "TestDebtor"
    },
    "detalles": []
}

print("Enviando POST...")
res = requests.post(url, json=data)
print(res.status_code)
print(res.text)

print("Verificando GET...")
res_get = requests.get(url)
ventas = res_get.json()
print("Ultima venta:")
print(ventas[-1])

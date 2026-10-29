"""
EF DGITI - API de inventario desplegada detrás de un Application Load Balancer.

Endpoints:
- GET  /health          -> chequeo liviano que usa el balanceador (sin base de datos).
- GET  /status          -> instancia que respondió, zona, versión y estado de la BD.
- GET  /api/items       -> lista de ítems (lee de la RÉPLICA de RDS).
- GET  /api/items/{id}  -> un ítem (lee de la réplica).
- POST /api/items       -> crea un ítem (escribe en la PRINCIPAL de RDS).
- GET  /api/stress      -> trabajo de CPU para las pruebas de carga.
- GET  /docs            -> Swagger UI generado por FastAPI.
"""

import logging
import socket
import time
import urllib.request
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

from app import config
from app.db import db

logger = logging.getLogger("uvicorn.error")
STARTED_AT = time.time()


def _instance_metadata() -> dict:
    """Lee instance-id y zona desde IMDSv2. Fuera de AWS devuelve el hostname."""
    base = "http://169.254.169.254/latest"
    try:
        token_req = urllib.request.Request(
            f"{base}/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "300"},
        )
        token = urllib.request.urlopen(token_req, timeout=0.5).read().decode()
        headers = {"X-aws-ec2-metadata-token": token}

        def get(path: str) -> str:
            req = urllib.request.Request(f"{base}/meta-data/{path}", headers=headers)
            return urllib.request.urlopen(req, timeout=0.5).read().decode()

        return {
            "instance_id": get("instance-id"),
            "availability_zone": get("placement/availability-zone"),
            "private_ip": get("local-ipv4"),
        }
    except Exception:  # noqa: BLE001 - fuera de EC2 no hay IMDS
        return {"instance_id": socket.gethostname(), "availability_zone": "local", "private_ip": "127.0.0.1"}


INSTANCE = _instance_metadata()


@asynccontextmanager
async def lifespan(_: FastAPI):
    # RDS puede tardar en aceptar conexiones; se reintenta sin tumbar la app,
    # así /health sigue respondiendo y el balanceador no saca la instancia.
    for attempt in range(1, 6):
        try:
            db.connect()
            logger.info("Base de datos conectada en el intento %s", attempt)
            break
        except Exception as exc:  # noqa: BLE001
            db.last_error = str(exc).splitlines()[0]
            logger.warning("BD no disponible (intento %s): %s", attempt, db.last_error)
            time.sleep(3)
    yield


app = FastAPI(
    title="EF DGITI - API de inventario",
    description="Servicio de la evaluación final desplegado en AWS con Terraform, ALB, Auto Scaling y RDS con réplica.",
    version=config.APP_VERSION,
    lifespan=lifespan,
)


class ItemIn(BaseModel):
    name: str = Field(min_length=1, max_length=120, examples=["Switch Cisco 2960"])


@app.get("/health", tags=["validación"])
def health():
    return {"status": "ok", "instance_id": INSTANCE["instance_id"]}


@app.get("/status", tags=["validación"])
def status():
    return {
        "service": config.APP_NAME,
        "version": config.APP_VERSION,
        **INSTANCE,
        "uptime_seconds": round(time.time() - STARTED_AT),
        "database": {
            "primary": db.ping(db.primary),
            "replica": db.ping(db.replica),
            "last_error": db.last_error,
        },
    }


def _require_db() -> None:
    if db.primary is None:
        raise HTTPException(status_code=503, detail=f"Base de datos no disponible: {db.last_error}")


@app.get("/api/items", tags=["inventario"])
def list_items(limit: int = Query(50, ge=1, le=200)):
    _require_db()
    rows = db.list_items(limit)
    return {"read_from": "replica", "served_by": INSTANCE["instance_id"], "count": len(rows), "items": rows}


@app.get("/api/items/{item_id}", tags=["inventario"])
def get_item(item_id: int):
    _require_db()
    item = db.get_item(item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Ítem no encontrado (puede tardar unos segundos en llegar a la réplica)")
    return item


@app.post("/api/items", status_code=201, tags=["inventario"])
def create_item(payload: ItemIn):
    _require_db()
    item = db.create_item(payload.name, created_by=INSTANCE["instance_id"])
    return {"written_to": "primary", **item}


def _count_primes(upper_bound: int) -> int:
    # Fuerza bruta a propósito: genera carga de CPU real y predecible.
    count = 0
    for number in range(2, upper_bound):
        if all(number % d for d in range(2, int(number**0.5) + 1)):
            count += 1
    return count


@app.get("/api/stress", tags=["desempeño"])
def stress(n: int = Query(20000, ge=100, le=200000)):
    start = time.perf_counter()
    primes = _count_primes(n)
    return {
        "n": n,
        "primes_found": primes,
        "elapsed_ms": round((time.perf_counter() - start) * 1000, 2),
        "served_by": INSTANCE["instance_id"],
        "availability_zone": INSTANCE["availability_zone"],
    }

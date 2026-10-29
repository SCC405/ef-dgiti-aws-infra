"""
Pruebas de la API. Corren en GitHub Actions contra SQLite, sin AWS.

- Pruebas unitarias: funciones puras (conteo de primos, armado de URLs).
- Pruebas de integración: la app completa vía TestClient + base de datos real (SQLite).
"""

import os

os.environ["DATABASE_URL"] = "sqlite://"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import config  # noqa: E402
from app.main import _count_primes, app  # noqa: E402


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


# ---------- unitarias ----------

def test_count_primes():
    assert _count_primes(10) == 4  # 2, 3, 5, 7
    assert _count_primes(100) == 25


def test_postgres_url_escapa_password(monkeypatch):
    monkeypatch.setattr(config, "DB_USER", "appadmin")
    url = config._postgres_url("db.local", "p@ss:word/1")
    assert "p%40ss%3Aword%2F1" in url
    assert url.startswith("postgresql+psycopg://appadmin:")


def test_database_urls_usa_replica(monkeypatch):
    monkeypatch.setattr(config, "DATABASE_URL", None)
    monkeypatch.setattr(config, "DB_HOST", "primary.rds")
    monkeypatch.setattr(config, "DB_REPLICA_HOST", "replica.rds")
    monkeypatch.setenv("DB_PASSWORD", "secreto")
    primary, replica = config.database_urls()
    assert "@primary.rds:" in primary
    assert "@replica.rds:" in replica


# ---------- integración ----------

def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_status_reporta_bd(client):
    body = client.get("/status").json()
    assert body["service"] == "ef-dgiti-api"
    assert body["database"]["primary"] == "ok"
    assert body["database"]["replica"] == "ok"
    assert "instance_id" in body


def test_crear_y_leer_item(client):
    r = client.post("/api/items", json={"name": "Router MikroTik"})
    assert r.status_code == 201
    created = r.json()
    assert created["written_to"] == "primary"

    r = client.get(f"/api/items/{created['id']}")
    assert r.status_code == 200
    assert r.json()["name"] == "Router MikroTik"

    listing = client.get("/api/items").json()
    assert listing["read_from"] == "replica"
    assert listing["count"] >= 1


def test_item_inexistente(client):
    assert client.get("/api/items/999999").status_code == 404


def test_validacion_nombre_vacio(client):
    assert client.post("/api/items", json={"name": ""}).status_code == 422


def test_stress(client):
    body = client.get("/api/stress", params={"n": 1000}).json()
    assert body["primes_found"] == 168
    assert body["elapsed_ms"] >= 0


def test_stress_limita_parametro(client):
    assert client.get("/api/stress", params={"n": 10_000_000}).status_code == 422


def test_reconecta_cuando_la_bd_vuelve(monkeypatch):
    from app import db as db_module

    database = db_module.Database()
    monkeypatch.setattr(db_module.config, "database_urls", lambda: (_ for _ in ()).throw(RuntimeError("SSM denegado")))
    assert database.ensure_connected() is False
    assert database.last_error == "SSM denegado"

    # Pasado el intervalo de reintento y con la BD disponible, se conecta sola.
    monkeypatch.setattr(db_module.config, "database_urls", lambda: ("sqlite://", "sqlite://"))
    database._last_attempt = float("-inf")
    assert database.ensure_connected() is True
    assert database.last_error is None
    assert database.ping(database.primary) == "ok"


def test_swagger_disponible(client):
    assert client.get("/docs").status_code == 200
    assert client.get("/openapi.json").json()["info"]["title"].startswith("EF DGITI")

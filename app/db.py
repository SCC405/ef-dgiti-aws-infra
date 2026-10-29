"""
Acceso a datos con SQLAlchemy Core.

Se manejan dos motores:
- primary: RDS principal. Recibe todas las escrituras.
- replica: réplica de lectura de RDS (otra zona de disponibilidad).
  Las consultas de lectura de la API van aquí para descargar a la principal.
"""

import time
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    Integer,
    MetaData,
    String,
    Table,
    create_engine,
    insert,
    select,
    text,
)
from sqlalchemy.engine import Engine
from sqlalchemy.pool import StaticPool

from app import config

metadata = MetaData()

items = Table(
    "items",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String(120), nullable=False),
    Column("created_by", String(64), nullable=False),
    Column("created_at", DateTime(timezone=True), nullable=False),
)


RETRY_SECONDS = 10


class Database:
    def __init__(self) -> None:
        self.primary: Engine | None = None
        self.replica: Engine | None = None
        self.last_error: str | None = None
        self._last_attempt = float("-inf")

    def connect(self) -> None:
        primary_url, replica_url = config.database_urls()
        primary = _make_engine(primary_url)
        metadata.create_all(primary)
        # Con SQLite en memoria la "réplica" es la misma base.
        self.replica = primary if replica_url == primary_url else _make_engine(replica_url)
        self.primary = primary
        self.last_error = None

    def ensure_connected(self) -> bool:
        """Conecta si aún no hay conexión, como máximo un intento cada RETRY_SECONDS.

        Si la instancia arranca cuando RDS o SSM todavía no responden (por ejemplo,
        mientras el laboratorio de AWS Academy está detenido), la app se recupera
        sola en cuanto vuelven, sin reiniciar el contenedor.
        """
        if self.primary is not None:
            return True
        if time.monotonic() - self._last_attempt < RETRY_SECONDS:
            return False
        self._last_attempt = time.monotonic()
        try:
            self.connect()
            return True
        except Exception as exc:  # noqa: BLE001 - se reporta en /status
            self.last_error = str(exc).splitlines()[0]
            return False

    def ping(self, engine: Engine | None) -> str:
        if engine is None:
            return "not_configured"
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            return "ok"
        except Exception as exc:  # noqa: BLE001 - se reporta, no se propaga
            self.last_error = str(exc).splitlines()[0]
            return "error"

    def create_item(self, name: str, created_by: str) -> dict:
        row = {"name": name, "created_by": created_by, "created_at": datetime.now(timezone.utc)}
        with self.primary.begin() as conn:
            result = conn.execute(insert(items).values(**row))
            row["id"] = result.inserted_primary_key[0]
        return row

    def list_items(self, limit: int = 50) -> list[dict]:
        query = select(items).order_by(items.c.id.desc()).limit(limit)
        with self.replica.connect() as conn:
            return [dict(r._mapping) for r in conn.execute(query)]

    def get_item(self, item_id: int) -> dict | None:
        with self.replica.connect() as conn:
            row = conn.execute(select(items).where(items.c.id == item_id)).first()
        return dict(row._mapping) if row else None


def _make_engine(url: str) -> Engine:
    if url.startswith("sqlite"):
        kwargs = {"connect_args": {"check_same_thread": False}}
        if url in ("sqlite://", "sqlite:///:memory:"):
            kwargs["poolclass"] = StaticPool
        return create_engine(url, **kwargs)
    return create_engine(url, pool_size=5, max_overflow=5, pool_pre_ping=True, pool_recycle=300)


db = Database()

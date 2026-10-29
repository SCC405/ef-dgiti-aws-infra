"""
Configuración de la aplicación, leída de variables de entorno.

En AWS las variables las define user_data.sh al arrancar el contenedor.
En las pruebas (pytest / GitHub Actions) no existe ninguna base de datos
real, así que se usa SQLite a través de DATABASE_URL.
"""

import os
from urllib.parse import quote_plus

APP_NAME = "ef-dgiti-api"
APP_VERSION = os.getenv("APP_VERSION", "dev")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")

# Conexión directa (pruebas / ejecución local).
DATABASE_URL = os.getenv("DATABASE_URL")
REPLICA_DATABASE_URL = os.getenv("REPLICA_DATABASE_URL")

# Conexión a RDS (producción). La contraseña NO viaja en variables:
# la app la lee de SSM Parameter Store usando el rol de la instancia.
DB_HOST = os.getenv("DB_HOST")
DB_REPLICA_HOST = os.getenv("DB_REPLICA_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "appdb")
DB_USER = os.getenv("DB_USER", "appadmin")
DB_PASSWORD_PARAM = os.getenv("DB_PASSWORD_PARAM")


def _read_db_password() -> str:
    if os.getenv("DB_PASSWORD"):
        return os.environ["DB_PASSWORD"]
    if not DB_PASSWORD_PARAM:
        raise RuntimeError("Falta DB_PASSWORD_PARAM para leer la contraseña de SSM")

    import boto3  # solo se necesita en AWS

    ssm = boto3.client("ssm", region_name=AWS_REGION)
    response = ssm.get_parameter(Name=DB_PASSWORD_PARAM, WithDecryption=True)
    return response["Parameter"]["Value"]


def _postgres_url(host: str, password: str) -> str:
    return (
        f"postgresql+psycopg://{DB_USER}:{quote_plus(password)}"
        f"@{host}:{DB_PORT}/{DB_NAME}?connect_timeout=3"
    )


def database_urls() -> tuple[str, str]:
    """Devuelve (url_primaria, url_replica)."""
    if DATABASE_URL:
        return DATABASE_URL, REPLICA_DATABASE_URL or DATABASE_URL

    if not DB_HOST:
        # Sin configuración: base local en memoria, útil para desarrollo.
        return "sqlite://", "sqlite://"

    password = _read_db_password()
    primary = _postgres_url(DB_HOST, password)
    replica = _postgres_url(DB_REPLICA_HOST, password) if DB_REPLICA_HOST else primary
    return primary, replica

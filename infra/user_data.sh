#!/bin/bash
# User Data: se ejecuta una vez, como root, en el primer arranque de cada
# instancia que crea el Auto Scaling Group. Registro en /var/log/cloud-init-output.log
#
# Terraform reemplaza los valores entre llaves con templatefile(). La
# contraseña de la base de datos NO aparece aquí: la app la lee de SSM
# Parameter Store usando el rol de la instancia (LabInstanceProfile).
set -euxo pipefail

export HOME=/root
export DEBIAN_FRONTEND=noninteractive
APT_WAIT="-o DPkg::Lock::Timeout=300"
APP_DIR=/opt/app

# 1. Docker y Git
apt-get $APT_WAIT update -y
apt-get $APT_WAIT install -y git docker.io
systemctl enable --now docker

# 2. Código fuente desde GitHub (la última versión de la rama desplegada)
git clone --depth 1 --branch "${repo_branch}" "${repo_url}" "$APP_DIR"
cd "$APP_DIR"
APP_VERSION="$(git rev-parse --short HEAD)"

# 3. Imagen y contenedor. --restart: si la instancia se reinicia, el contenedor vuelve solo.
docker build -t ef-dgiti-api .
docker run -d --name ef-dgiti-api --restart unless-stopped \
  -p ${app_port}:8000 \
  -e APP_VERSION="$APP_VERSION" \
  -e AWS_REGION="${region}" \
  -e DB_HOST="${db_host}" \
  -e DB_REPLICA_HOST="${db_replica_host}" \
  -e DB_NAME="${db_name}" \
  -e DB_USER="${db_user}" \
  -e DB_PASSWORD_PARAM="${db_password_param}" \
  ef-dgiti-api

echo "User Data terminado: version $APP_VERSION escuchando en el puerto ${app_port}"

#!/bin/bash
# Prepara la terminal del AWS Academy Learner Lab (o AWS CloudShell):
# instala Terraform en ~/bin y clona el repositorio en ~/ef-dgiti-aws-infra.
# Las credenciales ya vienen configuradas en esa terminal: no se copian a ningún lado.
#
#   curl -sL https://raw.githubusercontent.com/SCC405/ef-dgiti-aws-infra/main/scripts/lab-setup.sh | bash
set -euo pipefail

TF_VERSION=1.9.8
mkdir -p ~/bin

if ! ~/bin/terraform version >/dev/null 2>&1; then
  echo ">> Instalando Terraform $TF_VERSION"
  cd /tmp
  curl -sLo tf.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip"
  python3 -c "import zipfile; zipfile.ZipFile('tf.zip').extract('terraform', '$HOME/bin')"
  chmod +x ~/bin/terraform
  rm -f tf.zip
fi

grep -q 'HOME/bin' ~/.bashrc || echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc

if [ -d ~/ef-dgiti-aws-infra/.git ]; then
  git -C ~/ef-dgiti-aws-infra pull --ff-only
else
  git clone https://github.com/SCC405/ef-dgiti-aws-infra.git ~/ef-dgiti-aws-infra
fi

cd ~/ef-dgiti-aws-infra/infra
[ -f terraform.tfvars ] || cp terraform.tfvars.example terraform.tfvars

~/bin/terraform version
aws sts get-caller-identity --query Arn --output text
echo ">> Listo. Ejecutar:  source ~/.bashrc && cd ~/ef-dgiti-aws-infra/infra"

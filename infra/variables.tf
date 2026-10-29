variable "aws_region" {
  description = "Región de AWS. En AWS Academy Learner Lab es us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Prefijo de nombre para todos los recursos."
  type        = string
  default     = "ef-dgiti"
}

# ---------------------------------------------------------------------------
# Red
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Subredes públicas (ALB y NAT Gateway), una por zona."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "app_subnet_cidrs" {
  description = "Subredes privadas de aplicación (instancias EC2), una por zona."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "db_subnet_cidrs" {
  description = "Subredes privadas aisladas para RDS (sin salida a Internet), una por zona."
  type        = list(string)
  default     = ["10.20.21.0/24", "10.20.22.0/24"]
}

# ---------------------------------------------------------------------------
# Cómputo
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "Tipo de instancia de la aplicación (permitido por el Learner Lab)."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Mínimo de instancias: 2 para sobrevivir a la caída de una."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Instancias deseadas al desplegar."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Máximo de instancias cuando la carga dispara el escalado."
  type        = number
  default     = 4
}

variable "cpu_target" {
  description = "Porcentaje de CPU promedio que el Auto Scaling intenta mantener."
  type        = number
  default     = 50
}

variable "instance_profile_name" {
  description = "Perfil de instancia ya creado por AWS Academy (no se pueden crear roles IAM en el Learner Lab)."
  type        = string
  default     = "LabInstanceProfile"
}

# ---------------------------------------------------------------------------
# Aplicación
# ---------------------------------------------------------------------------

variable "repo_url" {
  description = "Repositorio público con el código de la aplicación."
  type        = string
  default     = "https://github.com/SCC405/ef-dgiti-aws-infra.git"
}

variable "repo_branch" {
  description = "Rama que se despliega."
  type        = string
  default     = "main"
}

variable "app_port" {
  description = "Puerto donde escucha el contenedor de la aplicación."
  type        = number
  default     = 8000
}

# ---------------------------------------------------------------------------
# Base de datos
# ---------------------------------------------------------------------------

variable "db_instance_class" {
  description = "Clase de la instancia RDS (principal y réplica)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "Versión mayor de PostgreSQL."
  type        = string
  default     = "17"
}

variable "db_name" {
  description = "Nombre de la base de datos de la aplicación."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos."
  type        = string
  default     = "appadmin"
}

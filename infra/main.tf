locals {
  name = var.project
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ---------------------------------------------------------------------------
# Datos existentes (no se crean, solo se consultan)
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Cuenta de AWS que entrega los access logs del ALB en us-east-1
data "aws_elb_service_account" "main" {}

data "aws_caller_identity" "current" {}

# ===========================================================================
# 1. RED: VPC con tres capas (pública / aplicación / datos) en dos zonas
# ===========================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-igw" }
}

# Capa pública: solo el ALB y el NAT Gateway viven aquí
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name}-public-${local.azs[count.index]}", Tier = "public" }
}

# Capa de aplicación: las EC2 no tienen IP pública
resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${local.name}-app-${local.azs[count.index]}", Tier = "private-app" }
}

# Capa de datos: aislada, sin ruta a Internet
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "${local.name}-db-${local.azs[count.index]}", Tier = "private-db" }
}

# NAT Gateway: permite a las EC2 privadas descargar paquetes y el código,
# sin aceptar conexiones entrantes desde Internet.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${local.name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${local.name}-nat" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name}-rt-public" }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${local.name}-rt-app" }
}

# Sin rutas extra: solo tráfico local dentro de la VPC
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-rt-db" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "db" {
  count          = 2
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# ===========================================================================
# 2. SEGURIDAD: Security Groups encadenados (Internet -> ALB -> EC2 -> RDS)
# ===========================================================================

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "ALB: HTTP 80 desde Internet"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-alb-sg" }
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "EC2 de la app: puerto de la app solo desde el ALB"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db-sg"
  description = "RDS: PostgreSQL 5432 solo desde las EC2 de la app"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.name}-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde Internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

# El ALB solo puede hablar con las instancias, en el puerto de la app
resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Hacia las EC2 de la app"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

# Origen = Security Group del ALB, no una IP: nadie más entra a las EC2
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Puerto de la app desde el ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

# Salida: apt, GitHub y SSM a través del NAT; PostgreSQL hacia RDS
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Salida a Internet via NAT y a RDS"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL desde las EC2 de la app"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

# ===========================================================================
# 3. ALMACENAMIENTO: bucket S3 para los access logs del balanceador
# ===========================================================================

resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${local.name}-alb-logs-${random_id.suffix.hex}"
  force_destroy = true
  tags          = { Name = "${local.name}-alb-logs" }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expirar-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ALBAccessLogs"
      Effect    = "Allow"
      Principal = { AWS = data.aws_elb_service_account.main.arn }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

# ===========================================================================
# 4. BASE DE DATOS: RDS PostgreSQL principal + réplica de lectura en otra AZ
# ===========================================================================

# Terraform genera la contraseña y la guarda cifrada en SSM Parameter Store.
# No aparece en el repositorio ni en el user data.
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${local.name}/db/password"
  description = "Contraseña de RDS para la app"
  type        = "SecureString"
  value       = random_password.db.result
}

resource "aws_db_subnet_group" "db" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id
  tags       = { Name = "${local.name}-db-subnets" }
}

resource "aws_db_instance" "primary" {
  identifier        = "${local.name}-db-primary"
  engine            = "postgres"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  availability_zone      = local.azs[0]
  publicly_accessible    = false

  # La réplica necesita copias de seguridad automáticas en la principal
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = { Name = "${local.name}-db-primary", Role = "primary" }
}

resource "aws_db_instance" "replica" {
  identifier          = "${local.name}-db-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = var.db_instance_class
  storage_encrypted   = true

  vpc_security_group_ids = [aws_security_group.db.id]
  availability_zone      = local.azs[1]
  publicly_accessible    = false

  skip_final_snapshot = true
  apply_immediately   = true

  tags = { Name = "${local.name}-db-replica", Role = "read-replica" }
}

# ===========================================================================
# 5. CÓMPUTO: Launch Template + Auto Scaling Group en subredes privadas
# ===========================================================================

resource "aws_launch_template" "app" {
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  # LabInstanceProfile: permite leer SSM y enviar métricas sin llaves en la instancia
  iam_instance_profile {
    name = var.instance_profile_name
  }

  # IMDSv2 obligatorio; hop limit 2 para que el contenedor Docker llegue al IMDS
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # Métricas de EC2 cada minuto en CloudWatch (por defecto son cada 5)
  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    repo_url          = var.repo_url
    repo_branch       = var.repo_branch
    app_port          = var.app_port
    region            = var.aws_region
    db_host           = aws_db_instance.primary.address
    db_replica_host   = aws_db_instance.replica.address
    db_name           = var.db_name
    db_user           = var.db_username
    db_password_param = aws_ssm_parameter.db_password.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-app" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${local.name}-app-volume" }
  }
}

# ===========================================================================
# 6. BALANCEO: Application Load Balancer en las dos subredes públicas
# ===========================================================================

resource "aws_lb" "app" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = { Name = "${local.name}-alb" }

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

resource "aws_lb_target_group" "app" {
  name                 = "${local.name}-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  vpc_id               = aws_vpc.main.id
  target_type          = "instance"
  deregistration_delay = 30

  # Si /health falla 2 veces seguidas, el ALB deja de enviarle tráfico
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${local.name}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${local.name}-asg"
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  vpc_zone_identifier       = aws_subnet.app[*].id
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 120

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Reemplazo gradual: nunca baja de la mitad de instancias sanas
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "${local.name}-app"
    propagate_at_launch = true
  }
}

# Escala para mantener la CPU promedio cerca del objetivo
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${local.name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target
  }
}

# ===========================================================================
# 7. MONITOREO: alarmas y dashboard de CloudWatch
# ===========================================================================

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${local.name}-unhealthy-hosts"
  alarm_description   = "Hay instancias que no pasan el health check del ALB"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-5xx"
  alarm_description   = "Más de 10 errores 5XX por minuto en el ALB"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${local.name}-latencia-alta"
  alarm_description   = "p95 del tiempo de respuesta mayor a 1 segundo"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }
}

locals {
  alb_dim = ["LoadBalancer", aws_lb.app.arn_suffix]
  tg_dim  = ["TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.app.arn_suffix]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "ALB - Solicitudes por minuto"
          region  = var.aws_region
          stat    = "Sum"
          period  = 60
          view    = "timeSeries"
          metrics = [["AWS/ApplicationELB", "RequestCount", local.alb_dim[0], local.alb_dim[1]]]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB - Tiempo de respuesta (s)"
          region = var.aws_region
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", local.alb_dim[0], local.alb_dim[1], { stat = "Average", label = "promedio" }],
            ["...", { stat = "p95", label = "p95" }],
            ["...", { stat = "p99", label = "p99" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "ALB - Códigos HTTP"
          region = var.aws_region
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", local.alb_dim[0], local.alb_dim[1], { label = "2XX" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { label = "4XX app" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { label = "5XX app" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { label = "5XX ALB" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Target Group - Instancias sanas / no sanas"
          region = var.aws_region
          stat   = "Maximum"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", local.tg_dim[0], local.tg_dim[1], local.tg_dim[2], local.tg_dim[3], { label = "sanas" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { label = "no sanas" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title   = "EC2 - CPU promedio del Auto Scaling Group (%)"
          region  = var.aws_region
          stat    = "Average"
          period  = 60
          view    = "timeSeries"
          metrics = [["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name]]
          annotations = {
            horizontal = [{ label = "objetivo de escalado", value = var.cpu_target }]
          }
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title  = "Auto Scaling - Instancias"
          region = var.aws_region
          stat   = "Maximum"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.app.name, { label = "en servicio" }],
            [".", "GroupDesiredCapacity", ".", ".", { label = "deseadas" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 18, width = 12, height = 6
        properties = {
          title  = "RDS - CPU y conexiones"
          region = var.aws_region
          stat   = "Average"
          period = 60
          view   = "timeSeries"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.primary.identifier, { label = "CPU principal" }],
            ["...", aws_db_instance.replica.identifier, { label = "CPU réplica" }],
            [".", "DatabaseConnections", ".", aws_db_instance.primary.identifier, { label = "conexiones principal", yAxis = "right" }],
            ["...", aws_db_instance.replica.identifier, { label = "conexiones réplica", yAxis = "right" }],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 18, width = 12, height = 6
        properties = {
          title   = "RDS - Retraso de la réplica (s)"
          region  = var.aws_region
          stat    = "Maximum"
          period  = 60
          view    = "timeSeries"
          metrics = [["AWS/RDS", "ReplicaLag", "DBInstanceIdentifier", aws_db_instance.replica.identifier]]
        }
      },
    ]
  })
}

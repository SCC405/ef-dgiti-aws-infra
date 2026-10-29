output "app_url" {
  description = "URL pública del servicio (a través del ALB)"
  value       = "http://${aws_lb.app.dns_name}"
}

output "health_url" {
  description = "Endpoint de validación"
  value       = "http://${aws_lb.app.dns_name}/health"
}

output "swagger_url" {
  description = "Documentación interactiva (Swagger UI)"
  value       = "http://${aws_lb.app.dns_name}/docs"
}

output "alb_dns_name" {
  description = "DNS del Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnets" {
  description = "Subredes por capa"
  value = {
    public = aws_subnet.public[*].id
    app    = aws_subnet.app[*].id
    db     = aws_subnet.db[*].id
  }
}

output "security_groups" {
  value = {
    alb = aws_security_group.alb.id
    app = aws_security_group.app.id
    db  = aws_security_group.db.id
  }
}

output "asg_name" {
  description = "Auto Scaling Group (lo usa el pipeline para el despliegue)"
  value       = aws_autoscaling_group.app.name
}

output "db_primary_endpoint" {
  description = "RDS principal (solo accesible desde la VPC)"
  value       = aws_db_instance.primary.address
}

output "db_replica_endpoint" {
  description = "Réplica de lectura de RDS en la otra zona"
  value       = aws_db_instance.replica.address
}

output "db_password_parameter" {
  description = "Parámetro SSM con la contraseña (cifrada)"
  value       = aws_ssm_parameter.db_password.name
}

output "alb_logs_bucket" {
  value = aws_s3_bucket.alb_logs.bucket
}

output "cloudwatch_dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards/dashboard/${aws_cloudwatch_dashboard.main.dashboard_name}"
}

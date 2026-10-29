terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Todas las piezas quedan etiquetadas: se filtran fácil en la consola y en costos.
  default_tags {
    tags = {
      Project   = var.project
      Course    = "DGITI - Evaluacion Final"
      ManagedBy = "Terraform"
    }
  }
}

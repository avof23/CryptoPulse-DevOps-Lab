#--------------------------------------------------------------------
# Terraform
# Provision:
#  Route53 Zone
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
provider "aws" {}

#-----Data Sources,Local vars----------------------------------------
data "aws_ssm_parameter" "current_project_name" {
  name = "/CryptoPulse/globalvars/project_name"
}

locals {
  project_name = data.aws_ssm_parameter.current_project_name.value
  ssm_prefix   = "/${local.project_name}"
}

data "aws_ssm_parameter" "env" {
  name = "${local.ssm_prefix}/globalvars/env"
}

locals {
  env = data.aws_ssm_parameter.env.value
}

data "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/${local.env}/network/vpc_id"
}

data "terraform_remote_state" "backend_lb" {
  backend "s3" {
    key = "CryptoPulse/test/vpc/application/ec2_app_asg/terraform.tfstate"
  }
}

data "terraform_remote_state" "db_address" {
  backend "s3" {
    key = "CryptoPulse/test/vpc/databases/mz_rds/terraform.tfstate"
  }
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  app_lb_url = data.terraform_remote_state.backend_lb.outputs.app-loadbalancer-url
  app_lb_zone = data.terraform_remote_state.backend_lb.outputs.app-loadbalancer-zone
  db_address = data.terraform_remote_state.db_address.outputs.database_address
}

#-----Remote State--------------------------------------------------
terraform {
    backend "s3" {
	key = "CryptoPulse/test/route53/terraform.tfstate"
    }
}

#-----Resources------------------------------------------------------
resource "aws_route53_zone" "private" {
  name = lower("${local.project_name}.internal")

  vpc {
    vpc_id = local.vpc_id
  }
}

resource "aws_route53_record" "app_alb_alias" {
  zone_id = aws_route53_zone.private.zone_id
  name    = lower("api.${local.project_name}.internal")
  type    = "A"

  alias {
    name                   = local.app_lb_url
    zone_id                = local.app_lb_zone
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "db_cname" {
  zone_id = aws_route53_zone.private.zone_id
  name    = lower("db.${local.project_name}.internal")
  type    = "CNAME"
  ttl     = 300

  records = [local.db_address]
}
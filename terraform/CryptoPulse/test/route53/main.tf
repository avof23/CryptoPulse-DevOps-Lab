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

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
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

#-----SSM PS Resource------------------------------------------------
resource "aws_ssm_parameter" "zone_id" {
  name  = "${local.ssm_prefix}/${local.env}/route53/zone_id"
  type  = "String"
  value = aws_route53_zone.private.zone_id
}

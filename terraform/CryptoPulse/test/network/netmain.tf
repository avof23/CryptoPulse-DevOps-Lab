#--------------------------------------------------------------------
# Terraform
# Provision:
#  VPC, igw, natgw, routing, subnets by module
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
provider "aws" {}

#-----Data Sources,Local vars----------------------------------------
data "aws_region" "current" {}

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
  region = data.aws_region.current.id
  env = data.aws_ssm_parameter.env.value
}

#-----Remote State--------------------------------------------------
terraform {
    backend "s3" {
	key = "CryptoPulse/test/network/terraform.tfstate"
    }
}

#-----Modules--------------------------------------------------------
module "vpc-stack" {
  source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_network"
  env = local.env
  vpc_cidr = "10.1.0.0/16"
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
  db_subnet_cidrs = ["10.1.21.0/24", "10.1.22.0/24"]
}

#-----SSM PS Resource------------------------------------------------
resource "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/${local.env}/network/vpc_id"
  type  = "String"
  value = module.vpc-stack.vpc_id
}

resource "aws_ssm_parameter" "cidr_block" {
  name  = "${local.ssm_prefix}/${local.env}/network/cidr_block"
  type  = "String"
  value = module.vpc-stack.vpc_cidr
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/public_subnet_ids"
  type  = "String"
  value = jsonencode(module.vpc-stack.public_subnet_ids)
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/private_subnet_ids"
  type  = "String"
  value = jsonencode(module.vpc-stack.private_subnet_ids)
}

resource "aws_ssm_parameter" "db_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/db_subnet_ids"
  type  = "String"
  value = jsonencode(module.vpc-stack.db_subnet_ids)
}
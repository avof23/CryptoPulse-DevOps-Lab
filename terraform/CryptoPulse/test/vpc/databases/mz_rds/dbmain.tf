#--------------------------------------------------------------------
# Terraform
# Provision:
#  Security Group by module
#  Password generation
#  RDS Multi AZ Instance
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
provider "aws" {}

#-----Remote State--------------------------------------------------
terraform {
    backend "s3" {
	key = "CryptoPulse/test/vpc/databases/mz_rds/terraform.tfstate"
    }
}

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

data "aws_ssm_parameter" "common_tags" {
  name = "${local.ssm_prefix}/globalvars/common_tags"
}

locals {
  env = data.aws_ssm_parameter.env.value
  common_tags = jsondecode(data.aws_ssm_parameter.common_tags.value)
}

data "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/${local.env}/network/vpc_id"
}

data "aws_ssm_parameter" "db_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/db_subnet_ids"
}

data "aws_ssm_parameter" "app-instances-sg_id" {
  name = "${local.ssm_prefix}}/${local.env}/vpc/application/ec2_app_asg/app-instances-sg_id"
}

locals {
  	vpc_id = data.aws_ssm_parameter.vpc_id.value
  	db_subnet_ids = jsondecode(data.aws_ssm_parameter.db_subnet_ids.value)
}

data "aws_ssm_parameter" "current_rds_password" {
  name = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_password"
  depends_on = [aws_ssm_parameter.db_password]
}

data "aws_ssm_parameter" "current_rds_user" {
  name = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_user"
  depends_on = [aws_ssm_parameter.db_user]
}

data "aws_ssm_parameter" "current_rds_dbname" {
  name = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_dbname"
  depends_on = [aws_ssm_parameter.db_name]
}

#-----Modules--------------------------------------------------------
module "rds-access" {
    source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_secgroup"
    env = local.env
    vpc_sg_id = local.vpc_id
    inbond_rule = {
	  port = var.database_port
	  protocol = "tcp"
	  cidr_block = null
      source_sg = data.aws_ssm_parameter.app-instances-sg_id.value
    }
}

#-----SSM Parametr Store---------------------------------------------
resource "random_password" "db_password" {
  length = 12
  special = true
  override_special = "#(){}-+$&@%^"
}

resource "aws_ssm_parameter" "db_password" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_password"
  type  = "SecureString"
  value = random_password.db_password.result
}

resource "aws_ssm_parameter" "db_user" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_user"
  type  = "SecureString"
  value = var.db_user
}

resource "aws_ssm_parameter" "db_name" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_dbname"
  type  = "String"
  value = var.db_name
}

#-----Create resource------------------------------------------------
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "${lower(local.project_name)}-rds-subnet-group"
  subnet_ids = local.db_subnet_ids
}

resource "aws_db_instance" "postgresql" {
  identifier             = "${lower(local.project_name)}-db"

  engine                 = "postgres"
  engine_version         = "16.13"
  instance_class         = element(var.image_type, local.env)

  allocated_storage      = var.db_init_size
  max_allocated_storage  = var.db_init_size * 2
  storage_type           = element(var.db_disk_type, local.env)

  db_name                = data.aws_ssm_parameter.current_rds_dbname.value
  username               = data.aws_ssm_parameter.current_rds_user.value
  password               = data.aws_ssm_parameter.current_rds_password.value

  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [module.rds-access.id]
  multi_az               = true
  publicly_accessible    = false

  skip_final_snapshot    = true
  depends_on = []
}
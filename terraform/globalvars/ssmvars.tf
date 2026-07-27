#--------------------------------------------------------------------
# Terraform
# Provision:
#  SSM Parameters Store
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
provider "aws" {}

#-----Remote State--------------------------------------------------
terraform {
    backend "s3" {
	key = "globalvars/terraform.tfstate"
    }
}

#-----SSM PS Resource------------------------------------------------
resource "aws_ssm_parameter" "env" {
  name  = "/${var.project_name}/globalvars/env"
  type  = "String"
  value = var.env
}

resource "aws_ssm_parameter" "project_name" {
  name  = "/${var.project_name}/globalvars/project_name"
  type  = "String"
  value = var.project_name
}

resource "aws_ssm_parameter" "common_tags" {
  name  = "/${var.project_name}/globalvars/common_tags"
  type  = "String"
  value = jsonencode(var.common_tags)
}

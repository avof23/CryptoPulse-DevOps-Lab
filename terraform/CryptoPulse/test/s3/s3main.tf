#--------------------------------------------------------------------
# Terraform
# Provision:
#  S3 Object Storage
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
provider "aws" {}

#-----Data Sources,Local vars----------------------------------------
data "aws_region" "current" {}

data "aws_ssm_parameter" "current_project_name" {
  name = "/CryptoPulse/globalvars/project_name"
}

locals {
  region = data.aws_region.current.id
  project_name = data.aws_ssm_parameter.current_project_name.value
}

#-----Remote State--------------------------------------------------
terraform {
    backend "s3" {
	key = "CryptoPulse/test/s3/terraform.tfstate"
    }
}

#-----Resource S3----------------------------------------------------
resource "aws_s3_bucket" "terraform_states" {
  bucket              = var.bucket_name
  bucket_namespace    = "global"
  force_destroy       = false
  object_lock_enabled = false
  region              = local.region
  tags                = {}
  tags_all            = {}
}

resource "aws_s3_bucket_versioning" "states_versioning" {
  bucket = aws_s3_bucket.terraform_states.id
  versioning_configuration {
    status = "Enabled"
  }
}

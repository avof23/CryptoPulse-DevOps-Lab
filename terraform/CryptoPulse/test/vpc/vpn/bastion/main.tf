#--------------------------------------------------------------------
# Terraform
# Provision:
#  Security Group by module
#  EC2 Instance
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
provider "aws" {}

#-----Remote State--------------------------------------------------
terraform {
    backend "s3" {
	key = "CryptoPulse/test/vpc/application/vpn/bastion/terraform.tfstate"
    }
}

#-----Data Sources,Local vars----------------------------------------
data "aws_ami" "working_ami" {
    owners = ["amazon"]
    most_recent = true
    filter {
    name = "name"
    values = ["debian-13-amd64-*"]
    }
}

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

data "aws_ssm_parameter" "common_tags" {
  name = "${local.ssm_prefix}/globalvars/common_tags"
}

locals {
  region = data.aws_region.current.id
  env = data.aws_ssm_parameter.env.value
  common_tags = jsondecode(data.aws_ssm_parameter.common_tags.value)
}

data "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/${local.env}/network/vpc_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/private_subnet_ids"
}

locals {
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids = jsondecode(data.aws_ssm_parameter.private_subnet_ids.value)
}

#-----Modules--------------------------------------------------------
module "sg-bastion" {
  source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_secgroup"
  env = local.env
  vpc_sg_id = local.vpc_id
  inbond_rule = {
  port = var.allow_ports
  protocol = "tcp"
  cidr_block = "0.0.0.0/0"
  source_sg = null
    }
}

#-----SSM PS Resource------------------------------------------------
resource "aws_ssm_parameter" "sg_bastion_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/application/vpn/bastion/sg_web_id"
  type  = "String"
  value = module.sg-bastion.sg_id
  depends_on = [module.sg-bastion]
}

resource "aws_ssm_parameter" "ssh_key_name" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/application/vpn/bastion/ssh_ansible_key"
  type  = "String"
  value = var.ssh_key_name
}

#-----create resources-----------------------------------------------
resource "aws_instance" "bastion_server" {
    count = 1
    instance_type = var.image_type
    ami = data.aws_ami.working_ami.id
    vpc_security_group_ids = [module.sg-bastion.sg_id]
    subnet_id =  local.private_subnet_ids[count.index]
    tags = merge(local.common_tags, {
	Name = "bastion_${count.index + 1}"
	OS = "Debian"
	Serv_type = "${local.env} jump-server"
    })

    user_data = file(var.init_script)
    key_name = var.ssh_key_name
}

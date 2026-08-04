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
	key = "CryptoPulse/test/vpc/application/ec2_app_asg/terraform.tfstate"
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
data "aws_availability_zones" "working_az" {}

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

data "aws_ssm_parameter" "public_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/public_subnet_ids"
}

data "aws_ssm_parameter" "web-instances-sg_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/application/ec2_web_asg/web-instances-sg_id"
}

data "aws_ssm_parameter" "ssh_key_name" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/application/vpn/bastion/ssh_ansible_key"
}

locals {
  	vpc_id = data.aws_ssm_parameter.vpc_id.value
  	private_subnet_ids = jsondecode(data.aws_ssm_parameter.private_subnet_ids.value)
	public_subnet_ids = jsondecode(data.aws_ssm_parameter.public_subnet_ids.value)
	ssh_access_key = data.aws_ssm_parameter.ssh_key_name.value
}

#-----Modules--------------------------------------------------------
module "alb-app-access" {
    source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_secgroup"
    env = local.env
    vpc_sg_id = local.vpc_id
    inbond_rule = {
		port = var.endpoint_port
		protocol = "tcp"
		cidr_block = null
		source_sg = data.aws_ssm_parameter.web-instances-sg_id.value
    }
}

module "app-access" {
    source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_secgroup"
    env = local.env
    vpc_sg_id = local.vpc_id
    inbond_rule = {
		port = lookup(var.allow_ports, local.env, ["8000"])
		protocol = "tcp"
		cidr_block = null
		source_sg = module.alb-app-access.sg_id
    }
}

#-----Create resources-----------------------------------------------
resource "aws_launch_template" "app-ltemplate" {
	name = "app-ltemplate"
	instance_type = lookup(var.image_type, local.env, "t3.micro")
	image_id = data.aws_ami.working_ami.id
	vpc_security_group_ids = [module.app-access.sg_id]
	key_name = local.ssh_access_key
	user_data = base64encode(file(var.init_script))

	lifecycle {
		create_before_destroy = true
	}
}

resource "aws_autoscaling_group" "app-asg" {
	name = "app-asg-${aws_launch_template.app-ltemplate.latest_version}"
	launch_template {
		id = aws_launch_template.app-ltemplate.id
		version = aws_launch_template.app-ltemplate.latest_version
	}
	min_size = 2
	max_size = 4
	min_elb_capacity = 2
	vpc_zone_identifier = local.private_subnet_ids
	health_check_type = "ELB"
	target_group_arns = [aws_lb_target_group.app-tg.arn]

	dynamic "tag" {
		for_each = merge(local.common_tags, {Name="App Server in ASG-v${aws_launch_template.app-ltemplate.latest_version}"})
		content {
			key = tag.key
			value = tag.value
			propagate_at_launch = true
		}
	}

	lifecycle {
                create_before_destroy = true
        }
}

resource "aws_lb" "app-alb" {
	name = "APP-Servers-HA-ALB"
	load_balancer_type = "application"
	subnets = local.private_subnet_ids
	security_groups = [module.alb-app-access.sg_id]
}

resource "aws_lb_target_group" "app-tg" {
	name = "AppServer-HA-TG"
	vpc_id = local.vpc_id
	port = var.endpoint_port
	protocol = var.loadbalancing_proto
	deregistration_delay = "30"

	health_check {
        path                = "/"       #Эндпоинт, например /api/health
        protocol            = var.loadbalancing_proto
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_listener" "alb-list" {
	load_balancer_arn = aws_lb.app-alb.arn
	port = var.loadbalancing_port
	protocol = var.loadbalancing_proto

	default_action {
		type = "forward"
		target_group_arn = aws_lb_target_group.app-tg.arn
	}
}

#-----SSM PS Resource------------------------------------------------
resource "aws_ssm_parameter" "app-instances-sg_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/application/ec2_app_asg/app-instances-sg_id"
  type  = "String"
  value = module.app-access.sg_id
}
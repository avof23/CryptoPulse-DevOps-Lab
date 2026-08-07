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
  region = data.aws_region.current.region
  env = data.aws_ssm_parameter.env.value
  common_tags = jsondecode(data.aws_ssm_parameter.common_tags.value)
}

data "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/${local.env}/network/vpc_id"
}

data "aws_ssm_parameter" "zone_id" {
  name  = "${local.ssm_prefix}/${local.env}/route53/zone_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/private_subnet_ids"
}

data "aws_ssm_parameter" "public_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/public_subnet_ids"
}

data "aws_ssm_parameter" "ssh_key_name" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/vpn/bastion/ssh_ansible_key"
}

data "aws_ssm_parameter" "sg_bastion_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/vpn/bastion/instance-sg_id"
}

data "aws_ssm_parameter" "sg_rds_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/instance-sg_id"
}

locals {
  	vpc_id = data.aws_ssm_parameter.vpc_id.value
  	private_subnet_ids = jsondecode(data.aws_ssm_parameter.private_subnet_ids.value)
	public_subnet_ids = jsondecode(data.aws_ssm_parameter.public_subnet_ids.value)
	ssh_access_key = data.aws_ssm_parameter.ssh_key_name.value
	sg_bastion_id = data.aws_ssm_parameter.sg_bastion_id.value
	sg_rds_id = data.aws_ssm_parameter.sg_rds_id.value
	zone_id = data.aws_ssm_parameter.zone_id.value
}

#-----Modules--------------------------------------------------------
module "alb-app-access" {
    source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_secgroup"
    env = local.env
    vpc_sg_id = local.vpc_id
	resource_name = "alb-app"
    inbond_rule = {
		port = []
		protocol = "tcp"
		cidr_block = null
		source_sg = null
    }
}

module "app-access" {
    source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_secgroup"
    env = local.env
    vpc_sg_id = local.vpc_id
	resource_name = "app"
    inbond_rule = {
		port = lookup(var.allow_ports, local.env, ["8000"])
		protocol = "tcp"
		cidr_block = null
		source_sg = module.alb-app-access.sg_id
    }
}

module "ssh-app-access" {
    source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_secgroup"
    env = local.env
    vpc_sg_id = local.vpc_id
	resource_name = "ssh-app"
    inbond_rule = {
		port = ["22"]
		protocol = "tcp"
		cidr_block = null
		source_sg = local.sg_bastion_id
    }
}

resource "aws_vpc_security_group_ingress_rule" "app_to_db" {
  security_group_id            = local.sg_rds_id
  referenced_security_group_id = module.app-access.sg_id
  ip_protocol                  = "tcp"
  from_port                    = var.database_port
  to_port                      = var.database_port
}

#-----Create resources-----------------------------------------------
resource "aws_launch_template" "app-ltemplate" {
	name = "app-ltemplate"
	instance_type = lookup(var.image_type, local.env, "t3.micro")
	image_id = data.aws_ami.working_ami.id
	vpc_security_group_ids = [module.app-access.sg_id, module.ssh-app-access.sg_id]
	iam_instance_profile {
		name = aws_iam_instance_profile.app_profile.name
	}
	key_name = local.ssh_access_key
	user_data = base64encode(<<-EOF
		#!/bin/bash
		export project="${local.project_name}"
		export env="${local.env}"
		export region="${local.region}"

		${file(var.init_script)}
		EOF
	)

	lifecycle {
		create_before_destroy = true
	}
}

resource "aws_autoscaling_group" "app-asg" {
	name_prefix         = "app-asg-"
	#name = "app-asg-${aws_launch_template.app-ltemplate.latest_version}"
	launch_template {
		id = aws_launch_template.app-ltemplate.id
		version = aws_launch_template.app-ltemplate.latest_version
	}
	min_size = 2
	max_size = 4
	min_elb_capacity = 2
	vpc_zone_identifier = local.private_subnet_ids
	health_check_type = "ELB" #EC2
	#health_check_grace_period = 3600
	target_group_arns = [aws_lb_target_group.app-tg.arn]

	instance_refresh {
		strategy = "Rolling"
		preferences {
			min_healthy_percentage = 50
		}
	}

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
	internal           = true
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
        path                = "/"       #Endpoint example /api/health
        protocol            = var.loadbalancing_proto
        matcher             = "200" #200-499
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

resource "aws_route53_record" "app_alb_alias" {
  zone_id = local.zone_id
  name    = lower("api.${local.project_name}.internal")
  type    = "A"

  alias {
    name                   = aws_lb.app-alb.dns_name
    zone_id                = aws_lb.app-alb.zone_id
    evaluate_target_health = true
  }
}

#-----SSM PS Resource------------------------------------------------
resource "aws_ssm_parameter" "app-instances-sg_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/application/ec2_app_asg/instance-sg_id"
  type  = "String"
  value = module.app-access.sg_id
}

resource "aws_ssm_parameter" "alb-app-instances-sg_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/application/ec2_app_asg/alb-instance-sg_id"
  type  = "String"
  value = module.alb-app-access.sg_id
}

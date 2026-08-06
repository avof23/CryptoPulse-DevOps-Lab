#--------------------------------------------------------------------
# Terraform module
# Provision:
#  - Security Group
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
resource "aws_security_group" "vpc_sg" {
  name ="${var.resource_name}-${var.env}-${var.vpc_sg_id}-sg"
  vpc_id      = var.vpc_sg_id
  tags = {
    Name = "${var.resource_name}-${var.env}-security group"
  }
}

locals {
  sg_rules_list = flatten([
    for port in var.inbond_rule.port : [
      for sg in var.inbond_rule.source_sg : {
        key       = "${port}_${sg}"
        port      = port
        source_sg = sg
      }
    ]
  ])
  sg_rules_map = {
	  for rule in local.sg_rules_list : rule.key => rule
  }
}

resource "aws_vpc_security_group_ingress_rule" "irule_cidr" {
  for_each = (var.inbond_rule.cidr_block != null && var.inbond_rule.cidr_block != "") ? toset(nonsensitive(var.inbond_rule.port)) : []

  security_group_id            = aws_security_group.vpc_sg.id
  cidr_ipv4                    = var.inbond_rule.cidr_block
  ip_protocol                  = var.inbond_rule.protocol
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_vpc_security_group_ingress_rule" "irule_sg" {
  for_each = length(var.inbond_rule.source_sg) > 0 ? nonsensitive(local.sg_rules_map) : {}

  security_group_id            = aws_security_group.vpc_sg.id
  referenced_security_group_id = each.value.source_sg
  ip_protocol                  = var.inbond_rule.protocol
  from_port                    = each.value.port
  to_port                      = each.value.port
}

resource "aws_vpc_security_group_egress_rule" "erule" {
  for_each = toset(nonsensitive(lookup(var.outbond_rule, "port")))
  	security_group_id = aws_security_group.vpc_sg.id

  	cidr_ipv4   = lookup(var.outbond_rule, "cidr_block")
  	ip_protocol = lookup(var.outbond_rule, "protocol")
	from_port   = lookup(var.outbond_rule, "protocol") == "-1" ? null : each.value
  	to_port     = lookup(var.outbond_rule, "protocol") == "-1" ? null : each.value
}

#--------------------------------------------------------------------
# Terraform module
# Provision:
#  - Security Group
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------

resource "aws_security_group" "vpc_sg" {
  name ="${var.env}-vpc-${var.vpc_sg_id}-sg"
  vpc_id      = var.vpc_sg_id
  tags = {
    Name = "${var.env}-security group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "irule" {
  for_each = toset(lookup(var.inbond_rule, "port", []))
  	security_group_id = aws_security_group.vpc_sg.id

  	cidr_ipv4         = lookup(var.inbond_rule, "cidr_block", null)
	referenced_security_group_id = lookup(var.inbond_rule, "source_sg", null)
  	ip_protocol       = lookup(var.inbond_rule, "protocol")
	from_port         = each.value
  	to_port           = each.value
}

resource "aws_vpc_security_group_egress_rule" "erule" {
  for_each = toset(lookup(var.outbond_rule, "port"))
  	security_group_id = aws_security_group.vpc_sg.id

  	cidr_ipv4   = lookup(var.outbond_rule, "cidr_block")
  	ip_protocol = lookup(var.outbond_rule, "protocol")
	from_port   = lookup(var.outbond_rule, "protocol") == "-1" ? null : each.value
  	to_port     = lookup(var.outbond_rule, "protocol") == "-1" ? null : each.value
}

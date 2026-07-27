output "data_working_az" {
	value = data.aws_availability_zones.working_az.names
}

output "data_working_ami" {
	value = data.aws_ami.working_ami.id
}

output "web-loadbalancer-url" {
	value = aws_lb.web-alb.dns_name
}

output "web-instances-sg_id" {
	value = module.web-access.sg_id
}
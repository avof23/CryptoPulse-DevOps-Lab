output "app-loadbalancer-url" {
	value = aws_lb.app-alb.dns_name
}

output "app-loadbalancer-zone" {
	value = aws_lb.app-alb.zone_id
}

output "app-instances-sg_id" {
	value = module.app-access.sg_id
}
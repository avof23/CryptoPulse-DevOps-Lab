
output "stack_vpc_id" {
	value = module.vpc-stack.vpc_id
}

output "vpc_cidr" {
  value = module.vpc-stack.vpc_cidr
}

output "public_subnet_ids" {
  value = module.vpc-stack.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc-stack.private_subnet_ids
}
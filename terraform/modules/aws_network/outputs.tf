output "vpc_id" {
  value = aws_vpc.env_vpc.id
}

output "vpc_cidr" {
  value = aws_vpc.env_vpc.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnets[*].id
}

output "db_subnet_ids" {
  value = aws_subnet.db_subnets[*].id
}
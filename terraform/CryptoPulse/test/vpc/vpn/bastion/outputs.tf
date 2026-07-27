
output "data_working_ami" {
	value = data.aws_ami.working_ami.id
}

output "sg_web_id" {
	value = module.sg-bastion.sg_id
}

output "instance_dns" {
	value = aws_instance.bastion_server[*].public_dns
}
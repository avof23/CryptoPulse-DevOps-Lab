#--------------------------------------------------------------------
# Terraform
# Provision:
#  Security Group by module
#  Password generation
#  RDS Multi AZ Instance
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
provider "aws" {}

#-----Remote State--------------------------------------------------
terraform {
    backend "s3" {
	key = "CryptoPulse/test/vpc/databases/mz_rds/terraform.tfstate"
    }
}

#-----Data Sources,Local vars----------------------------------------
data "aws_region" "current" {}

data "aws_ssm_parameter" "current_project_name" {
  name = "/CryptoPulse/globalvars/project_name"
}

locals {
  region = data.aws_region.current.region
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
  env = data.aws_ssm_parameter.env.value
  common_tags = jsondecode(data.aws_ssm_parameter.common_tags.value)
}

data "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/${local.env}/network/vpc_id"
}

data "aws_ssm_parameter" "zone_id" {
  name  = "${local.ssm_prefix}/${local.env}/route53/zone_id"
}

data "aws_ssm_parameter" "db_subnet_ids" {
  name  = "${local.ssm_prefix}/${local.env}/network/db_subnet_ids"
}

#data "aws_ssm_parameter" "app-instances-sg_id" {
#  name = "${local.ssm_prefix}/${local.env}/vpc/application/ec2_app_asg/instances-sg_id"
#}

data "aws_ssm_parameter" "bastion-instances-sg_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/vpn/bastion/instance-sg_id"
}

data "aws_ssm_parameter" "bastion_id" {
  name = "${local.ssm_prefix}/${local.env}/vpc/vpn/bastion/instance_id"
}

data "aws_ssm_parameter" "bastion_iam_role_name" {
  name = "${local.ssm_prefix}/${local.env}/vpc/vpn/bastion/iam_role_name"
}

locals {
  	vpc_id = data.aws_ssm_parameter.vpc_id.value
  	db_subnet_ids = jsondecode(data.aws_ssm_parameter.db_subnet_ids.value)
    zone_id = data.aws_ssm_parameter.zone_id.value
    bastion_id = data.aws_ssm_parameter.bastion_id.value
}

data "aws_ssm_parameter" "current_rds_user" {
  name = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_user"
  depends_on = [aws_ssm_parameter.db_user]
}

data "aws_ssm_parameter" "current_rds_dbname" {
  name = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_dbname"
  depends_on = [aws_ssm_parameter.db_name]
}

#-----Modules--------------------------------------------------------
module "rds-access" {
    source = "git@github.com:avof23/CryptoPulse-DevOps-Lab.git//terraform/modules/aws_secgroup"
    env = local.env
    vpc_sg_id = local.vpc_id
    inbond_rule = {
	  port = [var.database_port]
	  protocol = "tcp"
	  cidr_block = null
      source_sg = data.aws_ssm_parameter.bastion-instances-sg_id.value
    }
}

#-----SSM Parametr Store---------------------------------------------
#resource "random_password" "db_password" {
#  length = 12
#  special = true
#  override_special = "#(){}-+$&@%^"
#}
#
#resource "aws_ssm_parameter" "db_password" {
#  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_password"
#  type  = "SecureString"
#  value = random_password.db_password.result
#}
resource "aws_ssm_parameter" "rds_secret_arn" {
  name  = "/${local.project_name}/${local.env}/vpc/databases/mz_rds/secret_arn"
  type  = "String"
  value = aws_db_instance.postgresql.master_user_secret[0].secret_arn
}

resource "aws_ssm_parameter" "iam_policy_secstore" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/iam_policy_secstore"
  type  = "String"
  value = aws_iam_policy.rds_secrets_access.arn
}

resource "aws_ssm_parameter" "db_user" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_user"
  type  = "String"
  value = var.db_user
}

resource "aws_ssm_parameter" "db_name" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/rds_dbname"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "rds-instances-sg_id" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/databases/mz_rds/instance-sg_id"
  type  = "String"
  value = module.rds-access.sg_id
}

#-----Create resource------------------------------------------------
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "${lower(local.project_name)}-rds-subnet-group"
  subnet_ids = local.db_subnet_ids
}

resource "aws_db_instance" "postgresql" {
  identifier             = "${lower(local.project_name)}-db"

  engine                 = "postgres"
  engine_version         = "16.13"
  instance_class         = lookup(var.image_type, local.env)

  allocated_storage      = var.db_init_size
  max_allocated_storage  = var.db_init_size * 2
  storage_type           = lookup(var.db_disk_type, local.env)

  db_name                = data.aws_ssm_parameter.current_rds_dbname.value
  username               = data.aws_ssm_parameter.current_rds_user.value
  manage_master_user_password = true
  #password               = data.aws_ssm_parameter.current_rds_password.value

  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [module.rds-access.sg_id]
  multi_az               = true
  publicly_accessible    = false

  skip_final_snapshot    = true
  depends_on = []
}

resource "aws_route53_record" "db_cname" {
  zone_id = local.zone_id
  name    = lower("db.${local.project_name}.internal")
  type    = "CNAME"
  ttl     = 300

  records = [aws_db_instance.postgresql.address]
  depends_on = [aws_db_instance.postgresql]
}

resource "aws_iam_policy" "rds_secrets_access" {
  name        = "rds_secret_access"
  description = "Allow to read RDS master user secret from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_db_instance.postgresql.master_user_secret[0].secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_secrets_access_attach" {
  role       = data.aws_ssm_parameter.bastion_iam_role_name.value
  policy_arn = aws_iam_policy.rds_secrets_access.arn
}

#-----Initialize the database----------------------------------------
resource "null_resource" "db_migration" {
  triggers = {
    db_endpoint = aws_db_instance.postgresql.endpoint
  }
  depends_on = [
    aws_db_instance.postgresql,
    aws_ssm_parameter.db_name,
    aws_iam_policy.rds_secrets_access,
    aws_iam_role_policy_attachment.bastion_secrets_access_attach
  ]

  provisioner "local-exec" {
    command = <<EOT
      aws ssm send-command \
        --document-name "AWS-RunShellScript" \
        --targets "Key=instanceids,Values=${local.bastion_id}" \
        --parameters '{"commands":[
          "#!/bin/bash",
          "set -e",
          "mkdir -p /opt/${lower(local.project_name)}/logs",
          "echo \"Ожидание завершения настройки бастиона...\" > /opt/${lower(local.project_name)}/logs/dbinit.log",
          "while [ ! -f /opt/${lower(local.project_name)}/.provision_done ]; do sleep 5; done",
          "cd /opt/${lower(local.project_name)}",

          "echo \"Получение секретов из Secrets Manager...\" >> /opt/${lower(local.project_name)}/logs/dbinit.log",
          "SECRET_ARN=\"${aws_ssm_parameter.rds_secret_arn.value}\"",
          "SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text --region ${local.region})",

          "echo \"Извлечение данных из JSON...\" >> /opt/${lower(local.project_name)}/logs/dbinit.log",
          "which jq >/dev/null 2>&1 || (apt-get update -y && apt-get install -y jq)",
          "DB_USER=$(echo $SECRET_JSON | jq -r .username)",
          "DB_PASS=$(echo $SECRET_JSON | jq -r .password)",

          "echo \"Генерация .env файла...\" >> /opt/${lower(local.project_name)}/logs/dbinit.log",
          "cat <<EOF > .env",
          "DB_HOST=${aws_db_instance.postgresql.address}",
          "DB_NAME=${data.aws_ssm_parameter.current_rds_dbname.value}",
          "DB_USER=$DB_USER",
          "DB_PASSWORD=$DB_PASS",
          "EOF",

          "source venv/bin/activate",
          "echo \"Запуск миграций Alembic...\" >> /opt/${lower(local.project_name)}/logs/dbinit.log",
          "alembic upgrade head",
          "python seed_migration.py",
          "rm -f .env"
        ]}' \
        --region ${local.region}
    EOT
  }
}
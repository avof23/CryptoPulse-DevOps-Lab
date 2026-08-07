#--------------------------------------------------------------------
# Terraform
# Provision:
#  IAM Role
#  IAM Policy
#  IAM Instance Profile
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
data "aws_ssm_parameter" "iam_policy_ssmps" {
  name = "/${local.project_name}/${local.env}/vpc/vpn/bastion/iam_policy_ssmps"
}

data "aws_ssm_parameter" "iam_policy_secstore" {
  name = "/${local.project_name}/${local.env}/vpc/databases/mz_rds/iam_policy_secstore"
}

locals {
  policy_arn_ssmps = jsondecode(data.aws_ssm_parameter.iam_policy_ssmps.value)
  policy_arn_secstore = jsondecode(data.aws_ssm_parameter.iam_policy_secstore.value)
}

resource "aws_iam_role" "app_role" {
  name = "app_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_access_ssmps" {
  role       = aws_iam_role.app_role.name
  policy_arn = local.policy_arn_ssmps
}

resource "aws_iam_role_policy_attachment" "app_access_secstore" {
  role       = aws_iam_role.app_role.name
  policy_arn = local.policy_arn_secstore
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "app_instance_profile"
  role = aws_iam_role.app_role.name
}
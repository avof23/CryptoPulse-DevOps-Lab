#--------------------------------------------------------------------
# Terraform
# Provision:
#  IAM Role
#  IAM Policy
#  IAM Instance Profile
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
data "aws_ssm_parameter" "iam_policy_arns" {
  name = "/${local.project_name}/${local.env}/vpc/vpn/bastion/iam_policy_arns"
}

locals {
  policy_arns = jsondecode(data.aws_ssm_parameter.iam_policy_arns.value)
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

resource "aws_iam_role_policy_attachment" "app_access_attach" {
  count = length(local.policy_arns)
  role       = aws_iam_role.app_role.name
  policy_arn = local.policy_arns[count.index]
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "app_instance_profile"
  role = aws_iam_role.app_role.name
}
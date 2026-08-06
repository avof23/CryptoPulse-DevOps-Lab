#--------------------------------------------------------------------
# Terraform
# Provision:
#  IAM Role
#  IAM Policy
#  IAM Instance Profile
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------
data "aws_ssm_parameter" "rds_secret_arn" {
  name = "/${local.project_name}/${local.env}/vpc/databases/mz_rds/secret_arn"
}

#-----Create resources-----------------------------------------------
resource "aws_iam_role" "bastion_role" {
  name = "bastion_ssm_role"

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

resource "aws_iam_policy" "ssm_parameters_read" {
  name        = "bastion_read_db_secrets"
  description = "Allow Bastion to read DB credentials from SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.id}:*:parameter/*/*/vpc/databases/mz_rds/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "bastion_secrets_access" {
  name        = "bastion_rds_secret_access"
  description = "Allow Bastion to read RDS master user secret from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = data.aws_ssm_parameter.rds_secret_arn.value
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_params_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.ssm_parameters_read.arn
}

resource "aws_iam_role_policy_attachment" "bastion_secrets_access_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.bastion_secrets_access.arn
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion_instance_profile"
  role = aws_iam_role.bastion_role.name
}

#-----SSM PS Resource------------------------------------------------
resource "aws_ssm_parameter" "iam_policy_arns" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/vpn/bastion/iam_policy_arns"
  type  = "String"
  value = jsonencode([aws_iam_policy.ssm_parameters_read.arn, aws_iam_policy.bastion_secrets_access.arn])
}

#--------------------------------------------------------------------
# Terraform
# Provision:
#  IAM Role
#  IAM Policy
#  IAM Instance Profile
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------

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
  name        = "ssm_parameters_read"
  description = "Allow to read DB credentials from SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${local.region}:*:parameter/*/*/vpc/databases/mz_rds/*"
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

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_params_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.ssm_parameters_read.arn
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "bastion_instance_profile"
  role = aws_iam_role.bastion_role.name
}

#-----SSM PS Resource------------------------------------------------
resource "aws_ssm_parameter" "iam_role_name" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/vpn/bastion/iam_role_name"
  type  = "String"
  value = aws_iam_role.bastion_role.name
}

resource "aws_ssm_parameter" "iam_policy_arns" {
  name  = "${local.ssm_prefix}/${local.env}/vpc/vpn/bastion/iam_policy_ssmps"
  type  = "String"
  value = aws_iam_policy.ssm_parameters_read.arn
}

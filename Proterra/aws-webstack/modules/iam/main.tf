data "aws_iam_policy" "ssm_core" { arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }

# Create or reuse role/profile
locals {
  role_name    = length(var.reuse_role_name)        > 0 ? var.reuse_role_name        : "${var.name}-ec2-ssm-role"
  profile_name = length(var.reuse_instance_profile) > 0 ? var.reuse_instance_profile : "${var.name}-ec2-ssm-profile"
}

resource "aws_iam_role" "role" {
  count              = length(var.reuse_role_name) > 0 ? 0 : 1
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ec2.amazonaws.com"] }
  }
}
resource "aws_iam_instance_profile" "profile" {
  count = length(var.reuse_instance_profile) > 0 ? 0 : 1
  name  = local.profile_name
  role  = local.role_name
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = local.role_name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

# Optional narrow read policies (Secrets Manager + SSM parameters)
data "aws_iam_policy_document" "read_creds" {
  dynamic "statement" {
    for_each = length(var.secret_arns) > 0 ? [1] : []
    content {
      actions   = ["secretsmanager:GetSecretValue"]
      resources = var.secret_arns
    }
  }
  dynamic "statement" {
    for_each = length(var.parameter_arns) > 0 ? [1] : []
    content {
      actions   = ["ssm:GetParameter","ssm:GetParameters"]
      resources = var.parameter_arns
    }
  }
}

resource "aws_iam_policy" "read_creds" {
  count  = (length(var.secret_arns) + length(var.parameter_arns)) > 0 ? 1 : 0
  name   = "${var.name}-ec2-read-creds"
  policy = data.aws_iam_policy_document.read_creds.json
}
resource "aws_iam_role_policy_attachment" "read_creds_attach" {
  count     = (length(var.secret_arns) + length(var.parameter_arns)) > 0 ? 1 : 0
  role      = local.role_name
  policy_arn= aws_iam_policy.read_creds[0].arn
}

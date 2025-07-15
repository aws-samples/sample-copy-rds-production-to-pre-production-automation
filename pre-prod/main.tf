// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

resource "aws_kms_key" "main" {
  description             = "KMS key to be used for encrypting the AWS Backup Vault in pre-prod"
  enable_key_rotation     = var.enable_backup_kms_key_rotation
  deletion_window_in_days = var.backup_kms_key_deletion_window_in_days
  tags                    = var.tags
}

resource "aws_kms_alias" "backup" {
  name          = var.backup_kms_key_alias
  target_key_id = aws_kms_key.main.key_id
}

data "aws_iam_policy_document" "kms_key_policy" {
  #checkov:skip=CKV_AWS_109
  #checkov:skip=CKV_AWS_356
  #checkov:skip=CKV_AWS_111
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda_role.arn]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_key_policy" "kms_key_policy" {
  key_id = aws_kms_key.main.id
  policy = data.aws_iam_policy_document.kms_key_policy.json
}

resource "aws_backup_vault" "main" {
  name        = var.pre_prod_backup_vault_name
  tags        = var.tags
  kms_key_arn = aws_kms_key.main.arn
}

# Allow Prod Backup Service Role to copy to this Backup Vault
data "aws_iam_policy_document" "backup_vault_policy" {
  statement {
    sid    = "AccessProdRole"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.prod_account_id}:root"
      ]
    }

    actions = [
      "backup:CopyIntoBackupVault",
    ]

    resources = [aws_backup_vault.main.arn]
  }
}

resource "aws_backup_vault_policy" "backup" {
  backup_vault_name = aws_backup_vault.main.name
  policy            = data.aws_iam_policy_document.backup_vault_policy.json
}

# Create a Subnet group where the RDS DB resource will be launched
resource "aws_db_subnet_group" "main" {
  name       = var.rds_db_subnet_name
  subnet_ids = var.rds_db_subnets
  tags = merge(var.tags, {
    "copied-from-prod" = "true"
  })
}

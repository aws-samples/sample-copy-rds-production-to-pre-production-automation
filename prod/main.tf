// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

locals {
  schedule_config = {
    "daily" = {
      schedule     = "cron(0 ${var.backup_hour} * * ? *)"
      delete_after = 7
    }
    "weekly" = {
      schedule     = "cron(0 ${var.backup_hour} ? * SUN *)" # Every saturdays
      delete_after = 7
    }
    "monthly" = {
      schedule     = "cron(0 ${var.backup_hour} ? * SUN#1 *)" # Every saturdays
      delete_after = 14
    }
    "custom-schedule" = {
      schedule     = var.backup_custom_schedule
      delete_after = 90
    }
  }
}

resource "aws_kms_key" "backup" {
  #checkov:skip=CKV2_AWS_64:The default policy is good enough
  description             = "KMS key to be used for encrypting the AWS Backup Vault prod"
  enable_key_rotation     = var.enable_kms_key_rotation
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags                    = var.tags
}

resource "aws_kms_alias" "backup" {
  name          = var.backup_kms_key_alias
  target_key_id = aws_kms_key.backup.key_id
}

resource "aws_backup_vault" "main" {
  name        = var.prod_backup_vault_name
  kms_key_arn = aws_kms_key.backup.arn

  tags = var.tags
}

resource "aws_backup_plan" "main" {
  name = "${var.prod_backup_vault_name}-backup-plan"

  rule {
    rule_name         = "${var.prod_backup_vault_name}-backup-rule"
    target_vault_name = aws_backup_vault.main.name
    schedule          = local.schedule_config[var.backup_frequency].schedule

    copy_action {
      destination_vault_arn = "arn:aws:backup:${var.pre_prod_region}:${var.pre_prod_account_id}:backup-vault:${var.pre_prod_backup_vault_name}"

      lifecycle {
        cold_storage_after = 0
        delete_after       = 14
      }
    }

    lifecycle {
      cold_storage_after = 0
      delete_after       = local.schedule_config[var.backup_frequency].delete_after
    }

  }

  tags = var.tags
}

resource "aws_backup_selection" "this" {
  name         = "${var.prod_backup_vault_name}-resource"
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/AWSBackupDefaultServiceRole"
  plan_id      = aws_backup_plan.main.id

  resources = [
    "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:*",
    "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster:*"
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/CopyToPreProd"
      value = "true"
    }
  }
}

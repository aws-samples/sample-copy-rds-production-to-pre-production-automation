// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "region" {
  type        = string
  description = "The region where all resources should be deployed"
  default     = "eu-west-1"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "pre_prod_backup_vault_name" {
  type        = string
  description = "AWS Backup vault name in pre-prod account. This is where the RDS snapshots will be copied to. Should match with the pre-prod module input variable"
}

variable "prod_account_id" {
  type        = string
  description = "pre-prod AWS Account ID. The Backup will be copied to this account."
}

# RDS related variables
variable "rds_db_subnets" {
  type        = list(string)
  description = "A list of subnets where the RDS DB resource will be launched"
}

variable "rds_db_subnet_name" {
  type        = string
  description = "The name of the RDS subnet group that will be created. The RDS DB will be created in this subnet group."
  default     = "copy-to-pre-prod-example"
}

# KMS key for AWS Backup related variables
variable "enable_backup_kms_key_rotation" {
  type        = bool
  description = "Enables/Disables the KMS key rotation. Following the best practise, it is disabled by default."
  default     = false
}

variable "backup_kms_key_deletion_window_in_days" {
  type        = number
  description = "Duration in days after which the key is deleted after destruction of the resource. Must be between 7 and 30 days."
  default     = 30
}

variable "backup_kms_key_alias" {
  type        = string
  description = "The display name of the KMS key for encrypting AWS Backup Vault. The name must start with the word \"alias\" followed by a forward slash (alias/)."
  default     = "alias/aws-backup-pre-prod"

  validation {
    condition     = startswith(var.backup_kms_key_alias, "alias/")
    error_message = "The KMS key alias should start with \"alias/\""
  }
}

# Utility KMS key related variables
variable "enable_utility_kms_key_rotation" {
  type        = bool
  description = "Enables/Disables the Utility KMS key rotation. Following the best practise, it is disabled by default."
  default     = false
}

variable "utility_kms_key_deletion_window_in_days" {
  type        = number
  description = "Duration in days after which the utility kms key is deleted after destruction of the resource. Must be between 7 and 30 days."
  default     = 30
}

variable "utility_kms_key_alias" {
  type        = string
  description = "The display name of the utility KMS key. The name must start with the word \"alias\" followed by a forward slash (alias/)."
  default     = "alias/utility-key-pre-prod"

  validation {
    condition     = startswith(var.utility_kms_key_alias, "alias/")
    error_message = "The Utility KMS key alias should start with \"alias/\""
  }
}

# SNS topic name
variable "notification_sns_topic_name" {
  type        = string
  description = "The name of the SNS topic where the success/failure status of the restore process will be sent."
  default     = "notify-db-restore-result"
}

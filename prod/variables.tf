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

variable "prod_backup_vault_name" {
  type        = string
  description = "Name of AWS Backup vault to be created in the prod account."
  default     = "example-aws-backup-vault"
}

variable "pre_prod_backup_vault_name" {
  type        = string
  description = "AWS Backup vault name in pre-prod account. This is where the RDS snapshots will be copied to. Should match with the pre-prod module input variable"
}

variable "backup_frequency" {
  type        = string
  description = "Determine how often new snapshots are taken and copied to pre-prod environment"
  validation {
    condition     = contains(["daily", "weekly", "monthly", "custom-schedule"], var.backup_frequency)
    error_message = "Valid values for backup_frequency are daily, weekly, fortnightly and custom-schedule."
  }
  default = "weekly"
}

variable "backup_custom_schedule" {
  description = "The custom schedule for backup frequency. Will only be used when backup_frequency is set to custom-schedule. Defined as a AWS cron syntax."
  type        = string
  default     = ""
}

variable "backup_hour" {
  type        = number
  description = "Specify at which hour of day a new snapshot should be taken. From 0 to 23. Defaults to 2am in the morning"
  default     = 2
}

variable "pre_prod_account_id" {
  type        = string
  description = "pre-prod AWS Account ID. The Backup will be copied to this account."
}

variable "pre_prod_region" {
  type        = string
  description = "The region in pre-prod account where AWS Backup will copy the recovery points (backups) to. When not supplied, will be copied to same region as the prod Backup Valut"
  default     = ""
}

# KMS key related variables
variable "enable_kms_key_rotation" {
  type        = bool
  description = "Enables/Disables the KMS key rotation. Following the best practise, it is disabled by default."
  default     = false
}

variable "kms_key_deletion_window_in_days" {
  type        = number
  description = "Duration in days after which the key is deleted after destruction of the resource. Must be between 7 and 30 days."
  default     = 30
}

variable "backup_kms_key_alias" {
  type        = string
  description = "The display name of the KMS key for encrypting AWS Backup Vault. The name must start with the word \"alias\" followed by a forward slash (alias/)."
  default     = "alias/aws-backup-prod"

  validation {
    condition     = startswith(var.backup_kms_key_alias, "alias/")
    error_message = "The KMS key alias should start with \"alias/\""
  }
}


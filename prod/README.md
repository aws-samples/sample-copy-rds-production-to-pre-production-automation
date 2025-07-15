## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_backup_plan.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_kms_key.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup_custom_schedule"></a> [backup\_custom\_schedule](#input\_backup\_custom\_schedule) | The custom schedule for backup frequency. Will only be used when backup\_frequency is set to custom-schedule. Defined as a AWS cron syntax. | `string` | `""` | no |
| <a name="input_backup_frequency"></a> [backup\_frequency](#input\_backup\_frequency) | Determine how often new snapshots are taken and copied to pre-prod environment | `string` | `"weekly"` | no |
| <a name="input_backup_hour"></a> [backup\_hour](#input\_backup\_hour) | Specify at which hour of day a new snapshot should be taken. From 0 to 23. Defaults to 2am in the morning | `number` | `2` | no |
| <a name="input_pre_prod_account_id"></a> [pre\_prod\_account\_id](#input\_pre\_prod\_account\_id) | pre-prod AWS Account ID. The Backup will be copied to this account. | `string` | n/a | yes |
| <a name="input_pre_prod_backup_vault_name"></a> [pre\_prod\_backup\_vault\_name](#input\_pre\_prod\_backup\_vault\_name) | AWS Backup vault name in pre-prod account. This is where the RDS snapshots will be copied to. Should match with the pre-prod module input variable | `string` | n/a | yes |
| <a name="input_pre_prod_region"></a> [pre\_prod\_region](#input\_pre\_prod\_region) | pre-prod AWS Account ID. The Backup will be copied to this region. When not supplied, will be copied to same region as the prod | `string` | `""` | no |
| <a name="input_prod_backup_vault_name"></a> [prod\_backup\_vault\_name](#input\_prod\_backup\_vault\_name) | Name of AWS Backup vault to be created in the prod account. | `string` | `"example-aws-backup-vault"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

No outputs.

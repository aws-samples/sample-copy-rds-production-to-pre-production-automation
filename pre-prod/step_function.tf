// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

locals {
  cw_log_group_name = "/aws/step-functions/restore-db-in-pre-prod-step-function-workflow"
}
#
# Create a role for Step Function
data "aws_iam_policy_document" "step_function_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "restore_db_sfn_role" {
  name_prefix        = "restore-db-sfn-execution_role"
  assume_role_policy = data.aws_iam_policy_document.step_function_assume_role.json
}

# Create a permission policy for Step Functions
data "aws_iam_policy_document" "step_functions_logging_permissions" {
  #checkov:skip=CKV_AWS_111: The resource must be * due the reason mentioned in the link below
  #checkov:skip=CKV_AWS_356: We need * on describe operations
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:DescribeLogGroups",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    # The resource must be * many cloudwatch API actions do not support resource types
    # More information here https://docs.aws.amazon.com/step-functions/latest/dg/cw-logs.html#cloudwatch-iam-policy
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "step_functions_logging_policy" {
  name_prefix = "step-functions-logging-tracing-policy"
  description = "A Policy to allow logging and tracing for Step Functions"
  policy      = data.aws_iam_policy_document.step_functions_logging_permissions.json
}

# Allow the step function to relevent resources
data "aws_iam_policy_document" "restore_db_sfn_policy_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeAsync",
      "lambda:InvokeFunction",
      "lambda:InvokeFunctionUrl"
    ]
    resources = [aws_lambda_function.restore_db.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "sns:Publish",
    ]
    resources = [aws_sns_topic.notification.arn]
  }

  statement {
    effect  = "Allow"
    actions = ["rds:DescribeDBInstances"]
    resources = [
      "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/copied-from-prod"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
    ]
    resources = [aws_kms_key.utility_key.arn]
  }
}


resource "aws_iam_policy" "restore_db_sfn_policy" {
  name_prefix = "restore-db-sfn-permissions-policy"
  description = "A Policy to permit relevant access to restore DB Step Function"
  policy      = data.aws_iam_policy_document.restore_db_sfn_policy_permissions.json
}

resource "aws_iam_role_policy_attachment" "snapshot_restore_sfn_policy_attachment" {
  policy_arn = aws_iam_policy.restore_db_sfn_policy.arn
  role       = aws_iam_role.restore_db_sfn_role.name
}

resource "aws_iam_role_policy_attachment" "snapshot_restore_sfn_logging" {
  policy_arn = aws_iam_policy.step_functions_logging_policy.arn
  role       = aws_iam_role.restore_db_sfn_role.name
}

data "aws_iam_policy_document" "cloudwatch_kms_policy" {
  #checkov:skip=CKV_AWS_109
  #checkov:skip=CKV_AWS_111
  #checkov:skip=CKV_AWS_356
  statement {
    sid       = "Enable IAM user permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "Allow CloudWatch Logs Access"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.cw_log_group_name}"]
    }
  }
}

resource "aws_kms_key" "utility_key" {
  description             = "To be used for encrypting the CloudWatch log groups and Lambda functions in pre-prod"
  enable_key_rotation     = var.enable_utility_kms_key_rotation
  deletion_window_in_days = var.utility_kms_key_deletion_window_in_days
  policy                  = data.aws_iam_policy_document.cloudwatch_kms_policy.json
  tags                    = var.tags
}

resource "aws_kms_alias" "utility_key" {
  name          = var.utility_kms_key_alias
  target_key_id = aws_kms_key.utility_key.key_id
}

resource "aws_sns_topic" "notification" {
  name              = var.notification_sns_topic_name
  kms_master_key_id = aws_kms_key.utility_key.id
}

resource "aws_cloudwatch_log_group" "snapshot_restore_sfn_logs" {
  name              = local.cw_log_group_name
  retention_in_days = 365
  kms_key_id        = aws_kms_key.utility_key.arn
  tags              = var.tags
}

resource "aws_sfn_state_machine" "restore_db_workflow" {
  name_prefix = "restore-db-in-pre-prod"
  role_arn    = aws_iam_role.restore_db_sfn_role.arn
  definition = templatefile("${path.module}/templates/restore-db-sfn.asl.tftpl", {
    LAMBDA_FUNCTION_ARN = aws_lambda_function.restore_db.arn,
    SNS_TOPIC_ARN       = aws_sns_topic.notification.arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.snapshot_restore_sfn_logs.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tracing_configuration {
    enabled = true
  }
}

# Create IAM role to enable EventBridge to start Step Function execution
data "aws_iam_policy_document" "events_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "event_trigger_role" {
  name_prefix        = "events-role-to-execute-step-functions"
  assume_role_policy = data.aws_iam_policy_document.events_assume_role_policy.json
}

# Allow EventBridge role tp start Step Functions execution
data "aws_iam_policy_document" "allow_sfn_policy_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.restore_db_workflow.arn]
  }
}

resource "aws_iam_policy" "allow_sfn_policy" {
  name_prefix = "allow-step-function-execution"
  description = "A Policy to allow EventBridge to execute Step Function Workflow"
  policy      = data.aws_iam_policy_document.allow_sfn_policy_permissions.json
}

resource "aws_iam_role_policy_attachment" "eventbridge_sfn_execution_policy_attachment" {
  policy_arn = aws_iam_policy.allow_sfn_policy.arn
  role       = aws_iam_role.event_trigger_role.name
}

# Create a EventBridge rule to start above created Step Function when Snapshot
# copy completes
resource "aws_cloudwatch_event_rule" "recovery_point_copied" {
  name        = "copy-from-prod-to-pre-prod-completed"
  description = "The Backup Recovery Point has been copied into pre-prod account Backup vault"

  event_pattern = jsonencode({
    source      = ["aws.backup"]
    detail-type = ["Recovery Point State Change", "Recovery Point Change"]
    "detail" : {
      "status" : ["COMPLETED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "snapshot_restore_workflow_trigger" {
  target_id = "start_step_function_execution"
  rule      = aws_cloudwatch_event_rule.recovery_point_copied.name
  arn       = aws_sfn_state_machine.restore_db_workflow.arn
  role_arn  = aws_iam_role.event_trigger_role.arn
}

// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name_prefix        = "database_restore_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance",
      "rds:AddTagsToResource",
      "rds:ModifyDBInstance",
      "rds:DescribeDBClusterAutomatedBackups",
      "rds:DescribeDBClusters",
      "rds:DescribeDBInstances",
      "rds:RestoreDBInstanceFromDBSnapshot",
    ]
    resources = [
      "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:*",
      "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster:*",
      aws_db_subnet_group.main.arn
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
      "rds:DescribeDBClusterAutomatedBackups",
      "rds:DescribeDBClusterSnapshots",
      "rds:DescribeDBSnapshotAttributes",
      "rds:RestoreDBClusterFromSnapshot",
      "rds:RestoreDBInstanceFromDBSnapshot",
    ]
    resources = [
      "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:snapshot:awsbackup:*",
      "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:db:*",
      "arn:aws:rds:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster:*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/CopyToPreProd"
      values   = ["true"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.main.arn]
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

  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::*:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name_prefix = "restore-db-lambda-permissions-policy"
  policy      = data.aws_iam_policy_document.lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_policy_attachement" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function/lambda_handler.py"
  output_path = "lambda_handler.zip"
}

resource "aws_lambda_function" "restore_db" {
  #checkov:skip=CKV_AWS_115: No need for concurrent execution controls
  #checkov:skip=CKV_AWS_272: No need for code signing as well.
  #checkov:skip=CKV_AWS_116: No need for DLQ, failures are sent via SNS
  #checkov:skip=CKV_AWS_117: No need to run inside a VPC. Not accessing private resources
  function_name    = "restore-database-from-aws-backup"
  filename         = "lambda_handler.zip"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_handler.lambda_handler"
  runtime          = "python3.13"
  timeout          = 900
  source_code_hash = data.archive_file.lambda.output_base64sha256
  kms_key_arn      = aws_kms_key.utility_key.arn
  environment {
    variables = {
      DB_DUBNET_GROUP_NAME = aws_db_subnet_group.main.name
    }
  }
  tracing_config {
    mode = "Active"
  }
}

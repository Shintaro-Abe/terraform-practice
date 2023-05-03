data "aws_region" "current" {}
locals{
  region = data.aws_region.current.name
}
output "region" {
  value = local.region
}

data "aws_caller_identity" "current" {}
locals{
  account_id = data.aws_caller_identity.current.account_id
}
output "account_id" {
  value = local.account_id
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "cost.py"
  output_path = "cost.zip"
}

#Lambdaの実行ロールにアタッチするポリシー
data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [ "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${var.lambda_name}:*" ]
  }
}

data "aws_iam_policy_document" "lambda_sns" {
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [ "arn:aws:sns:${local.region}:${local.account_id}:${var.topic_name}" ]
  }
}

data "aws_iam_policy_document" "lambda_cost" {
  statement {
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage"
    ]
    resources = [ "*" ]
  }
}

#Lambdaの信頼ポリシー
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = [ "sts:AssumeRole" ]
    principals {
      type = "Service"
      identifiers = [ "lambda.amazonaws.com" ]
    }
  }
}

#StepFunctionsを呼び出すポリシー
data "aws_iam_policy_document" "stepfunction_start" {
  statement {
    effect = "Allow"
    actions = [
      "states:StartExecution"
    ]
    resources = [ "arn:aws:states:${local.region}:${local.account_id}:stateMachine:${var.statemachine_name}" ]
  }
}

#EventBridgeの信頼ポリシー
data "aws_iam_policy_document" "event_assume_role" {
  statement {
    actions = [ "sts:AssumeRole" ]
    principals {
      type = "Service"
      identifiers = [ "scheduler.amazonaws.com" ]
    }
  }
}

#Stepfunctionsの実行ポリシー
data "aws_iam_policy_document" "stepfunction_exe" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [ 
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.lambda_name}",
      "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.lambda_name}:*"
    ]
  }
}

data "aws_iam_policy_document" "stepfunction_logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]
    resources = [ "*" ]         #StepFunctionのログを取得するポリシーはresourceをワイルドカード" * "にする
  }
}

#Stepfunctionsの信頼ポリシー
data "aws_iam_policy_document" "stepfunctions_assume_role" {
  statement {
    actions = [ "sts:AssumeRole" ]
    principals {
      type = "Service"
      identifiers = [ "states.amazonaws.com" ]
    }
  }
}
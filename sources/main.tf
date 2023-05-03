#SNSの作成。
resource "aws_sns_topic" "cost_sns" {
  name = var.topic_name
  display_name = "Cost Notification"
}

resource "aws_sns_topic_subscription" "subscription" {
  topic_arn = aws_sns_topic.cost_sns.arn
  protocol = "email"
  endpoint = var.email_address
}

#Lambda用CloudWatch Loggroupの作成
resource "aws_cloudwatch_log_group" "lambda_log" {
  name = "/aws/lambda/${var.lambda_name}"
}

#StepFunctions用CloudWatch Loggroupの作成
resource "aws_cloudwatch_log_group" "statemachine_log" {
  name = "/aws/vendedlogs/states/${var.statemachine_name}"
}

#Lambdaの実行ロール
resource "aws_iam_policy" "lambda_logging" {
  name = "lambda_logging"
  path = "/"
  policy = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_policy" "lambda_sns" {
  name = "lambda_sns"
  path = "/"
  policy = data.aws_iam_policy_document.lambda_sns.json
}

resource "aws_iam_policy" "lambda_cost" {
  name = "lambda_cost"
  path = "/"
  policy = data.aws_iam_policy_document.lambda_cost.json
}

resource "aws_iam_role" "lambda_role" {
  name = "costnotification"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  managed_policy_arns = [
    aws_iam_policy.lambda_logging.arn,
    aws_iam_policy.lambda_sns.arn, 
    aws_iam_policy.lambda_cost.arn
  ]
}

#StepFunctionを呼び出すロール
resource "aws_iam_policy" "stepfunction_start" {
  name = "event_statemachine"
  path = "/"
  policy = data.aws_iam_policy_document.stepfunction_start.json
}

resource "aws_iam_role" "event_role" {
  name = "event_costnotification"
  assume_role_policy = data.aws_iam_policy_document.event_assume_role.json
  managed_policy_arns = [aws_iam_policy.stepfunction_start.arn]
}

#StepFunctionsの実行ロール
resource "aws_iam_policy" "stepfunction_exe" {
  name = "stepfunction_exe"
  path = "/"
  policy = data.aws_iam_policy_document.stepfunction_exe.json
}

resource "aws_iam_policy" "stepfunction_logging" {
  name = "stepfunction_logging"
  path = "/"
  policy = data.aws_iam_policy_document.stepfunction_logging.json
}

resource "aws_iam_role" "statemachine_role" {
  name = "statemachine_role"
  assume_role_policy = data.aws_iam_policy_document.stepfunctions_assume_role.json
  managed_policy_arns = [aws_iam_policy.stepfunction_exe.arn, aws_iam_policy.stepfunction_logging.arn]
}

#Lambdaの作成
resource "aws_lambda_function" "cost_lambda" {
  function_name = var.lambda_name
  filename = "cost.zip"
  role = aws_iam_role.lambda_role.arn
  handler = "cost.handler"
  runtime = "python3.9"
  environment {
    variables = {
      topic: aws_sns_topic.cost_sns.arn
    }
  }
}

#StepFunctionsの作成
resource "aws_sfn_state_machine" "cost_statemachine" {
  name = var.statemachine_name
  role_arn = aws_iam_role.statemachine_role.arn
  definition = <<EOF
{
  "StartAt": "Lambda Invoke",
  "States": {
    "Lambda Invoke": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:${local.region}:${local.account_id}:function:${var.lambda_name}"
      },
      "End": true
    }
  }
}
EOF

  logging_configuration {
    log_destination = "${aws_cloudwatch_log_group.statemachine_log.arn}:*"
    include_execution_data = true
    level = "ALL"
  }
}

#EventBridgeの作成
resource "aws_scheduler_schedule" "cost_eventbridge" {
  name = "cost_statemachine_event"
  schedule_expression = "cron(0 3 * * ? *)"
  flexible_time_window {
    mode = "OFF"
  }
  target {
    arn = aws_sfn_state_machine.cost_statemachine.arn
    role_arn = aws_iam_role.event_role.arn
  }
}
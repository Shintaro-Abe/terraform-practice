#Eメールアドレス
variable "email_address" {
  type    = string
  default = "xxxxxxxxxxxx@icloud.com"
}

#Topicのリソースネーム
variable "topic_name" {
  type    = string
  default = "cost-notification"
}

#Lambdaのリソースネーム
variable "lambda_name" {
  type    = string
  default = "costnotification"
}

#Stepfunctionsのリソースネーム
variable "statemachine_name" {
  type    = string
  default = "cost-statemachine"
}
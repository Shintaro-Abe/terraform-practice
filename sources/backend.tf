terraform {
  backend "s3" {
    bucket = "abetest-terraform-deploymentbucket"
    key    = "abetest-dev/terraform.tfstate"
		encrypt = true
    region = "ap-northeast-1"
  }
}
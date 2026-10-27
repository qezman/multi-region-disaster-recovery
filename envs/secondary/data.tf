data "terraform_remote_state" "primary" {
  backend = "s3"
  config = {
    bucket = "dr-project-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "primary/terraform.tfstate"
    region = "eu-west-1"
  }
}
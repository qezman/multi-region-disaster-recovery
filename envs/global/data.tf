# reads the primary region's outputs from its tf state
data "terraform_remote_state" "primary" {
  backend = "s3"
  config = {
    bucket = "dr-project-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "primary/terraform.tfstate"
    region = "eu-west-1"
  }
}

# reads the secondary region's outputs from its tf state
data "terraform_remote_state" "secondary" {
  backend = "s3"
  config = {
    bucket = "dr-project-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "secondary/terraform.tfstate"
    region = "eu-west-1"
  }
}
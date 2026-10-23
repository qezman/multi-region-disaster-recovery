# This configures the backend storage to isolate the sec region infrastructure state
terraform {
  backend "s3" {
    bucket       = "dr-project-tfstate-722965867897"
    key          = "secondary/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
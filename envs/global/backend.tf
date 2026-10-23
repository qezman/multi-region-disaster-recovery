terraform {
  backend "s3" {
    bucket       = "dr-project-tfstate-722965867897"
    key          = "global/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
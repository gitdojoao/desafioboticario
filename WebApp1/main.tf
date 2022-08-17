terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.21.0"
    }
  }

  backend "s3" {
    bucket = "${var.domain}-terraform"
    key    = "dev/WebServer1.tfstate"
    region = "us-east-1"
  }
}
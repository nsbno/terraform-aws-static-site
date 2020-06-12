provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  region = "us-east-1"
  alias = "certificate_provider"
}

data "aws_vpc" "main" {
  default = true
}

data "aws_subnet_ids" "main" {
  vpc_id = data.aws_vpc.main.id
}

module "static-example" {
  source           = "../../"
  providers = {
    aws.certificate_provider = aws.certificate_provider
  }
  name_prefix      = "static-example"
  hosted_zone_name = "example.com"
  site_name        = "static-example.example.com"
}


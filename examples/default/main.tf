provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  region = "us-east-1"
  alias  = "certificate_provider"
}

resource "aws_route53_zone" "main" {
  name = "example.com"
}

module "static-example" {
  source = "../../"
  providers = {
    aws.certificate_provider = aws.certificate_provider
  }
  name_prefix = "static-example"
  domain_zones = {
    "static-example.example.com" = aws_route53_zone.main.id
  }
}


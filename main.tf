# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
provider "aws" {
  # Module expects aws.certificate_provider set to us-east-1 to be passed in via the "providers" argument
  alias = "certificate_provider"
}

data "aws_caller_identity" "current-account" {}

locals {
  domains = sort(keys(var.domain_zones))
  validation_options_by_domain_name = {
    for opt in aws_acm_certificate.cert_website.domain_validation_options : opt.domain_name => merge(opt, {
      # NOTE: `try` catches the error that occurs when `domain_validation_options` references a domain
      # that has been removed from `var.domain_zones`
      zone_id = try(var.domain_zones[opt.domain_name], keys(var.domain_zones)[0])
    })
  }
}

resource "aws_acm_certificate" "cert_website" {
  domain_name               = local.domains[0]
  validation_method         = "DNS"
  provider                  = aws.certificate_provider
  subject_alternative_names = slice(local.domains, 1, length(local.domains))
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_website_validation" {
  # NOTE: The `try` methods make sure that `terraform apply` succeeds despite using out-of-date `domain_validation_options`
  # This may lead to invalid validation records, in which case the `aws_acm_certificate_validation` will time out.
  # Running `terraform apply` again should fix such a situation.
  depends_on      = [aws_acm_certificate.cert_website]
  for_each        = var.domain_zones
  name            = try(local.validation_options_by_domain_name[each.key].resource_record_name, values(local.validation_options_by_domain_name)[0].resource_record_name)
  type            = try(local.validation_options_by_domain_name[each.key].resource_record_type, values(local.validation_options_by_domain_name)[0].resource_record_type)
  zone_id         = try(local.validation_options_by_domain_name[each.key].zone_id, values(local.validation_options_by_domain_name)[0].zone_id)
  records         = [try(local.validation_options_by_domain_name[each.key].resource_record_value, values(local.validation_options_by_domain_name)[0].resource_record_value)]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.cert_website.arn
  provider                = aws.certificate_provider
  validation_record_fqdns = values(aws_route53_record.cert_website_validation).*.fqdn
  timeouts {
    create = var.certificate_validation_timeout
  }
}

data "aws_s3_bucket" "website_bucket" {
  bucket = (var.website_bucket == "" ? aws_s3_bucket.website_bucket[0].id : var.website_bucket)
}

resource "aws_s3_bucket" "website_bucket" {
  count  = (var.use_external_bucket == false ? 1 : 0)
  bucket = "${data.aws_caller_identity.current-account.account_id}-${var.name_prefix}-static-website-bucket"
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

  versioning {
    enabled = var.bucket_versioning
  }
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = data.aws_s3_bucket.website_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "origin access identity for s3/cloudfront"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_acm_certificate_validation.main,
  ]

  origin {
    domain_name = data.aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = aws_cloudfront_origin_access_identity.origin_access_identity.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = local.domains

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  default_cache_behavior {
    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    target_origin_id = aws_cloudfront_origin_access_identity.origin_access_identity.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  price_class = "PriceClass_200"

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert_website.arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_record" "www_a" {
  for_each = var.domain_zones
  name     = "${each.key}."
  type     = "A"
  zone_id  = each.value
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.website_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [data.aws_s3_bucket.website_bucket.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}


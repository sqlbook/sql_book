resource "aws_s3_bucket" "cdn" {
  bucket = "cdn.sqlbook.com"
}

resource "aws_s3_bucket_cors_configuration" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["POST"]
    allowed_origins = ["https://sqlboob.com"]
    expose_headers  = []
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cdn" {
  bucket = aws_s3_bucket.cdn.id

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "cdn" {
  bucket = aws_s3_bucket.cdn.bucket
  policy = data.aws_iam_policy_document.cdn.json
}

data "aws_iam_policy_document" "cdn" {
  policy_id = "cdn.sqlbook.com"

  statement {
    sid       = "Cloudfront"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cdn.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.cdn.iam_arn]
    }
  }
}

provider "aws" {
  alias  = "north-virginia"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cdn" {
  domain_name       = "cdn.sqlbook.com"
  validation_method = "DNS"
  provider          = aws.north-virginia

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "cdn.sqlbook"
  }
}

resource "aws_route53_record" "cdn" {
  for_each = {
    for dvo in aws_acm_certificate.cdn.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = aws_route53_zone.sqlbook.id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 300
  allow_overwrite = true
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  comment             = "cdn.sqlbook.com"
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = ["cdn.sqlbook.com"]

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "sqlbook"
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    min_ttl                    = 0
    default_ttl                = 3600
    max_ttl                    = 86400
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cdn.id

    forwarded_values {
      query_string = false
      headers      = ["Referer"]

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = aws_s3_bucket.cdn.bucket_domain_name
    origin_id   = "sqlbook"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.cdn.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cdn.arn
    minimum_protocol_version = "TLSv1.2_2018"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudfront_response_headers_policy" "cdn" {
  name    = "sqlbook"
  comment = "cdn.sqlbook.com"

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["Referer"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_expose_headers {
      items = ["*"]
    }

    origin_override = false
  }
}

resource "aws_cloudfront_origin_access_identity" "cdn" {
  comment = "sqlbook"
}

resource "aws_route53_record" "cdn_a" {
  name    = "sqlbook"
  type    = "A"
  zone_id = aws_route53_zone.sqlbook.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
  }
}

resource "aws_route53_record" "aaaa" {
  name    = "cdn.sqlbook.com"
  type    = "AAAA"
  zone_id = aws_route53_zone.sqlbook.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
  }
}

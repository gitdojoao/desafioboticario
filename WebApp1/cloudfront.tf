resource "aws_cloudfront_distribution" "mywebsite" {
  depends_on = ["aws_acm_certificate_validation.cert_validation_virginia"]
  origin {
    domain_name = "${aws_s3_bucket.mywebsite.bucket_domain_name}"
    origin_id   = "${var.name}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["${var.domain}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    compress = true
    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn = "${aws_acm_certificate.domain_virginia.arn}"
    ssl_support_method = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  origin {
	domain_name = replace(aws_api_gateway_resource.service.rest_api_id, "/^https?://([^/]*).*/", "$1")
	origin_id   = "apigw"
	origin_path = "/stage"

	custom_origin_config {
		http_port              = 80
		https_port             = 443
		origin_protocol_policy = "https-only"
		origin_ssl_protocols   = ["TLSv1.2"]
	}
  }
}

resource "aws_route53_record" "mywebsite_record" {
  zone_id = "${aws_route53_zone.route_zone.zone_id}"
  name    = var.name
  type    = "A"

  alias {
    name = "${aws_cloudfront_distribution.mywebsite.domain_name}"
    zone_id = "${aws_cloudfront_distribution.mywebsite.hosted_zone_id}"
    evaluate_target_health = false
  }
}
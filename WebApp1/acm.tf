resource "aws_route53_zone" "route_zone" {
  name = "${var.domain}"
}

resource "aws_acm_certificate" "domain_virginia" {
  provider = "aws.virginia"
  domain_name = "${var.domain}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation_virginia" {
  name = "${aws_acm_certificate.domain_virginia.domain_validation_options.0.resource_record_name}"
  type = "${aws_acm_certificate.domain_virginia.domain_validation_options.0.resource_record_type}"
  records = ["${aws_acm_certificate.domain_virginia.domain_validation_options.0.resource_record_value}"]
  zone_id = "${aws_route53_zone.route_zone.zone_id}"
  ttl = 60
}

resource "aws_acm_certificate_validation" "cert_validation_virginia" {
  provider = "aws.virginia"
  certificate_arn = "${aws_acm_certificate.domain_virginia.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation_virginia.fqdn}"]
}

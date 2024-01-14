data "aws_route53_zone" "default" {
  count        = var.dns["use_route53"] ? 1 : 0
  provider     = aws.dns
  name         = var.dns["hosted_zone"]
  private_zone = var.dns["private_zone"]
}

resource "aws_route53_record" "default" {
  count    = var.dns["use_route53"] ? 1 : 0
  provider = aws.dns
  zone_id  = data.aws_route53_zone.default[0].id
  name     = var.dns["hostname"]
  type     = "A"

  alias {
    name                   = "dualstack.${aws_lb.default.dns_name}"
    zone_id                = aws_lb.default.zone_id
    evaluate_target_health = true
  }
}

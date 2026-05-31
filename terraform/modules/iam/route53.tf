# Route53 hosted zone + ACM DNS validation (Bonus 5.2)
# Only created when domain_name variable is set

data "aws_route53_zone" "app" {
  count        = var.domain_name != "" ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "acm_validation" {
  for_each = var.domain_name != "" ? {
    for dvo in aws_acm_certificate.app[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.app[0].zone_id
}

resource "aws_acm_certificate_validation" "app" {
  count                   = var.domain_name != "" ? 1 : 0
  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

# ALB DNS name is passed in from k8s module output after ingress is created
variable "alb_dns_name" {
  type    = string
  default = ""
}

variable "alb_zone_id" {
  type    = string
  default = ""
}

resource "aws_route53_record" "app_alb" {
  count   = var.domain_name != "" && var.alb_dns_name != "" ? 1 : 0
  zone_id = data.aws_route53_zone.app[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

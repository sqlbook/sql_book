resource "aws_ses_domain_identity" "sqlbook" {
  domain = "sqlbook.com"
}

resource "aws_ses_domain_dkim" "sqlbook" {
  domain = aws_ses_domain_identity.sqlbook.domain
}

resource "aws_ses_domain_mail_from" "sqlbook" {
  domain = aws_ses_domain_identity.sqlbook.domain
  mail_from_domain = "bounce.sqlbook.com"
}

resource "aws_route53_record" "amazonses_verification_record" {
  zone_id = aws_route53_zone.sqlbook.zone_id
  name    = "_amazonses.sqlbook.com"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.sqlbook.verification_token]
}

resource "aws_route53_record" "amazonses_dkim_record" {
  count   = 3
  zone_id = aws_route53_zone.sqlbook.zone_id
  name    = "${aws_ses_domain_dkim.sqlbook.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.sqlbook.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "ses_domain_mail_from_mx" {
  zone_id = aws_route53_zone.sqlbook.id
  name    = aws_ses_domain_mail_from.sqlbook.mail_from_domain
  type    = "MX"
  ttl     = "600"
  records = ["10 feedback-smtp.eu-west-1.amazonses.com"]
}

resource "aws_route53_record" "ses_domain_mail_from_txt" {
  zone_id = aws_route53_zone.sqlbook.id
  name    = aws_ses_domain_mail_from.sqlbook.mail_from_domain
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com -all"]
}

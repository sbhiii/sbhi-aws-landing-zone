# Apex zones for domains whose registration lives in this account, per
# decision 13. These carry mail, so they are the opposite case to the homelab
# zone in dns.tf: no automation ever writes into them, and nothing here is
# delegated to a workload.
#
# Record values are variables rather than literals because one of these domains
# receives account root email, which docs/security.md keeps out of this
# repository. The shape is in terraform.tfvars.example.
#
# Creating a zone changes nothing on its own. A zone only becomes authoritative
# once the registration's nameservers point at its delegation set, which is a
# separate manual step. That separation is what makes migrating a live mail
# domain safe: the new zone can be built and verified while the old one is still
# serving.
resource "aws_route53_zone" "mail" {
  for_each = var.mail_zones

  name    = each.key
  comment = "Apex zone. Mail records only, no automation writes here."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "mail_mx" {
  for_each = var.mail_zones

  zone_id = aws_route53_zone.mail[each.key].zone_id
  name    = each.key
  type    = "MX"
  ttl     = each.value.ttl
  records = each.value.mx
}

resource "aws_route53_record" "mail_txt" {
  for_each = { for k, v in var.mail_zones : k => v if length(v.txt) > 0 }

  zone_id = aws_route53_zone.mail[each.key].zone_id
  name    = each.key
  type    = "TXT"
  ttl     = each.value.ttl
  records = each.value.txt
}

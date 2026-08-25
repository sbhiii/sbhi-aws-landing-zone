# Registrations held in this account, per decision 13. These do not create or
# destroy anything: aws_route53domains_registered_domain manages the settings of
# a registration that already exists, and removing it from state leaves the
# domain registered.
#
# What it does manage is the two things that fail quietly. auto_renew decides
# whether a domain silently disappears on its expiry date, and name_server
# decides where it resolves. Both were previously only console state, with no
# record of what was intended.
#
# name_server is bound to the zone's own delegation set rather than to a
# variable, so the registration cannot drift away from the zone that serves it
# and a typo cannot point a live mail domain at nothing.
resource "aws_route53domains_registered_domain" "mail" {
  for_each = var.mail_zones

  domain_name   = each.key
  auto_renew    = each.value.auto_renew
  transfer_lock = each.value.transfer_lock

  dynamic "name_server" {
    for_each = aws_route53_zone.mail[each.key].name_servers
    content {
      name = name_server.value
    }
  }
}

# Registrations with no hosted zone in this account. Their nameservers are
# deliberately left unmanaged, because there is nothing here to point them at.
resource "aws_route53domains_registered_domain" "unserved" {
  for_each = var.unserved_domains

  domain_name   = each.key
  auto_renew    = each.value.auto_renew
  transfer_lock = each.value.transfer_lock
}

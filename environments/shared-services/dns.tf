# Subdomain delegated from the apex zone, which is held at an external DNS
# provider, edited by hand, and carries the MX records for account recovery.
# Delegating a subdomain keeps automation structurally unable to reach those
# records: see decision 12. The homelab runs outside AWS, so it takes a
# top-level delegation rather than sitting under a hub zone.
#
# Only the zone is defined here. Every record inside it, including the ACME
# challenge records cert-manager writes, belongs to the cluster's own repository,
# which finds this zone with a data source rather than through shared state. The
# split and its reasoning are decision 14.
#
# prevent_destroy because recovery is not an apply: a replacement zone gets a new
# ID and a new delegation set, so the NS records have to be corrected by hand at
# the external provider. That manual step is the whole reason decision 14 places
# this zone here rather than in the cluster's repository.
resource "aws_route53_zone" "homelab" {
  name    = var.homelab_zone_name
  comment = "Delegated to the homelab cluster. Records managed in sre-homelab."

  lifecycle {
    prevent_destroy = true
  }
}

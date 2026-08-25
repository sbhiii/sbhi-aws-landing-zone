output "homelab_zone_name_servers" {
  description = "Create these as the NS records for the subdomain at the external DNS provider. Until that is done the delegation does not exist and nothing in the zone resolves."
  value       = aws_route53_zone.homelab.name_servers
}

output "mail_zone_name_servers" {
  description = "Per zone, the delegation set to point the registration at. Until that is done the zone is inert and the old one keeps serving, which is what makes the cutover safe."
  value       = { for k, z in aws_route53_zone.mail : k => z.name_servers }
}

output "homelab_zone_id" {
  description = "Zone ID, for confirming a delegation by hand. The cluster's repository does not consume this: it looks the zone up by name."
  value       = aws_route53_zone.homelab.zone_id
}

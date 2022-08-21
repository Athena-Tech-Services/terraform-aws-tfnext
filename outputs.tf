#########
# Outputs
#########

output "cloudfront_domain_name" {
  value = local.enable_tf_next == 0 ? null : module.tf_next[0].cloudfront_domain_name
}

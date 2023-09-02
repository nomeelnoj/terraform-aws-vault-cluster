<!-- BEGIN_TF_DOCS -->
<!-- THESE DOCS ARE GENERATED.  Update doc.md in the .github/docs directory to make changes.
Update this file with the following command from the root of the repo:
terraform-docs -c ./.github/docs/.terraform-docs.yml .
-->
# Terraform AWS Vault Cluster

This module allows relatively opinionated creation of either an Enterprise or OSS vault cluster in AWS.

Please note that due to the nature of Vault, additional configuration will be required after creation. All required information for setup can be found in this README or in the [docs](./docs) folder in this repository.

## Configuration

Configuration examples can be found in the [examples](./examples) folder.

- [Basic Cluster](./examples/basic/vault_cluster.tf)
- [Full Configuration](./examples/full/vault_cluster.tf)

To configure if the cluster will be enterprise or OSS, you need only set two values:

```hcl
module "vault_cluster" {
  # ... removed for brevity
    vault_version = "1.14.2+ent-1" # The binary version determines enterprise or not

    enterprise_license_bucket = "my-vault-enterprise-license-bucket"
    enterprise_license_s3_key = "vault.hclic"
}
```

If using enterprise, you will also need to make sure that the IAM role created by this module has access to pull the license from the bucket.

NOTE: The terraform provider for the enterprise license bucket MUST be set, even if you are not using enterprise. You can simply alias the provider to the same account and it wont be used at all. The module passes a data block for this bucket to make sure the bucket exists to try and avoid issues with license access that may occur after apply time.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alt_names"></a> [alt_names](#input_alt_names) | Alt names for the cert | `list(string)` | `null` | no |
| <a name="input_ami_id"></a> [ami_id](#input_ami_id) | The ami id to use if you want to override the default most recent ubuntu image | `string` | `null` | no |
| <a name="input_arch"></a> [arch](#input_arch) | The architecture to use--arm64 or amd64 | `string` | `"arm64"` | no |
| <a name="input_audit_log_path"></a> [audit_log_path](#input_audit_log_path) | The file path to the audit log | `string` | `"/opt/log/vault-audit.log"` | no |
| <a name="input_auto_join_tag_key"></a> [auto_join_tag_key](#input_auto_join_tag_key) | The AWS tag key to use for node self discovery | `string` | `null` | no |
| <a name="input_auto_join_tag_value"></a> [auto_join_tag_value](#input_auto_join_tag_value) | The AWS tag value to use for node self discovery | `string` | `"server"` | no |
| <a name="input_aws_region"></a> [aws_region](#input_aws_region) | The region to which you are deploying | `string` | `"us-east-1"` | no |
| <a name="input_bucket"></a> [bucket](#input_bucket) | The name of the s3 bucket to create for backup | `string` | n/a | yes |
| <a name="input_create_key_name"></a> [create_key_name](#input_create_key_name) | The name of the SSH key to create | `string` | n/a | yes |
| <a name="input_disable_mlock"></a> [disable_mlock](#input_disable_mlock) | Whether to disable mlock | `bool` | `true` | no |
| <a name="input_disable_performance_standby"></a> [disable_performance_standby](#input_disable_performance_standby) | Whether to disable performance standby | `bool` | `true` | no |
| <a name="input_disable_sealwrap"></a> [disable_sealwrap](#input_disable_sealwrap) | Whether to disable sealwrap | `bool` | `true` | no |
| <a name="input_enterprise_license_bucket"></a> [enterprise_license_bucket](#input_enterprise_license_bucket) | The name of the bucket where the enterprise license file is stored | `string` | `null` | no |
| <a name="input_enterprise_license_s3_key"></a> [enterprise_license_s3_key](#input_enterprise_license_s3_key) | The name of the s3 key to use for the enterprise license | `string` | `"vault.hclic"` | no |
| <a name="input_force_destroy"></a> [force_destroy](#input_force_destroy) | Set to true if you want terraform to destroy the bucket, even if it has data | `bool` | `false` | no |
| <a name="input_generate_local_cert"></a> [generate_local_cert](#input_generate_local_cert) | Whether to generate a local cert or use vault. Good for first time setups before you have a vault to bootstrap | `bool` | `false` | no |
| <a name="input_health_check_matcher"></a> [health_check_matcher](#input_health_check_matcher) | The health check codes to map against. Add 472 for DR replicas | `string` | `"200"` | no |
| <a name="input_health_check_path"></a> [health_check_path](#input_health_check_path) | The path to use for health checks.  For uninitialized nodes, use /v1/sys/health?activecode=200&standbycode=200&sealedcode=200&uninitcode=200 for the health_check_path. | `string` | `"/v1/sys/health"` | no |
| <a name="input_hosted_zone"></a> [hosted_zone](#input_hosted_zone) | The name of the hosted zone to use | `string` | `null` | no |
| <a name="input_hostname"></a> [hostname](#input_hostname) | The hostname for the vault cluster | `string` | n/a | yes |
| <a name="input_iam_assume_role_policies"></a> [iam_assume_role_policies](#input_iam_assume_role_policies) | A map of assume role policies for the iam role | <pre>map(object({<br>    sid    = optional(string)<br>    effect = optional(string, "Allow")<br>    principals = list(object({<br>      type        = string<br>      identifiers = list(string)<br>    }))<br>    actions = list(string)<br>    conditions = optional(list(object({<br>      test     = string<br>      variable = string<br>      values   = list(string)<br>    })), null)<br>  }))</pre> | `{}` | no |
| <a name="input_iam_policy_attachments"></a> [iam_policy_attachments](#input_iam_policy_attachments) | A list of aws managed policies to attach to the iam role | `list(string)` | `[]` | no |
| <a name="input_iam_policy_statements"></a> [iam_policy_statements](#input_iam_policy_statements) | A map of policy statements to apply to the iam role | <pre>map(object({<br>    sid         = optional(string)<br>    effect      = optional(string, "Allow")<br>    actions     = list(string)<br>    not_actions = optional(list(string))<br>    resources   = optional(list(string))<br>    conditions = optional(list(object({<br>      test     = string<br>      variable = string<br>      values   = list(string)<br>    })))<br>  }))</pre> | `{}` | no |
| <a name="input_instance_type"></a> [instance_type](#input_instance_type) | The instance type to use for cluster instances | `string` | `"t4g.medium"` | no |
| <a name="input_kms_admin_arns"></a> [kms_admin_arns](#input_kms_admin_arns) | A list of ARNs for roles or users that should be able to administer the key but not use it | `list(string)` | `null` | no |
| <a name="input_kms_policy_statements"></a> [kms_policy_statements](#input_kms_policy_statements) | A map of policy statements to apply to the kms key use for vault unsealing | <pre>map(object({<br>    sid    = string<br>    effect = string<br>    principals = list(object({<br>      type        = string<br>      identifiers = list(string)<br>    }))<br>    actions = list(string)<br>    conditions = optional(list(object({<br>      test     = string<br>      variable = string<br>      values   = list(string)<br>    })), [])<br>  }))</pre> | `null` | no |
| <a name="input_load_balancer_ingress_cidrs"></a> [load_balancer_ingress_cidrs](#input_load_balancer_ingress_cidrs) | The ingress cidrs to allow for the load balancer | `list(string)` | n/a | yes |
| <a name="input_log_retention"></a> [log_retention](#input_log_retention) | The log retention for vault server logs | `number` | `731` | no |
| <a name="input_max_session_duration"></a> [max_session_duration](#input_max_session_duration) | The max session duration for the iam role | `number` | `3600` | no |
| <a name="input_node_count"></a> [node_count](#input_node_count) | The number of nodes in the cluster.  Must be an odd number greater than or equal to 3 | `number` | `3` | no |
| <a name="input_operator_log_path"></a> [operator_log_path](#input_operator_log_path) | The file path to the operator log | `string` | `"/var/log/vault-operator.log"` | no |
| <a name="input_private_zone"></a> [private_zone](#input_private_zone) | Whether the route53 zone is private or not | `bool` | `true` | no |
| <a name="input_s3_policy_statements"></a> [s3_policy_statements](#input_s3_policy_statements) | A map of policy statements for the s3 bucket | <pre>map(object({<br>    sid    = string<br>    effect = string<br>    principals = optional(list(object({<br>      type        = string<br>      identifiers = list(string)<br>    })))<br>    not_principals = optional(list(object({<br>      type        = string<br>      identifiers = list(string)<br>    })))<br>    actions       = optional(list(string))<br>    not_actions   = optional(list(string))<br>    resources     = optional(list(string), [])<br>    not_resources = optional(list(string))<br>    conditions = optional(list(object({<br>      test     = string<br>      variable = string<br>      values   = list(string)<br>    })))<br>  }))</pre> | `{}` | no |
| <a name="input_sse"></a> [sse](#input_sse) | The type of encryption to use on the s3 bucket | `string` | `"AES256"` | no |
| <a name="input_ssh_ingress_cidrs"></a> [ssh_ingress_cidrs](#input_ssh_ingress_cidrs) | The ingress cidrs for SSH to nodes | `list(string)` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh_public_key](#input_ssh_public_key) | The public key to use when creating an SSH key | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids) | The list of subnet IDs to use when deploying vault | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input_tags) | A map of key value tags to apply to all AWS resources | `map(string)` | n/a | yes |
| <a name="input_ttl"></a> [ttl](#input_ttl) | The TTL of the cert | `string` | `"8760h"` | no |
| <a name="input_ui"></a> [ui](#input_ui) | Whether to enable the UI | `bool` | `true` | no |
| <a name="input_use_route53"></a> [use_route53](#input_use_route53) | Whether to use route53. If not selected, hostname will not be managed. | `bool` | `true` | no |
| <a name="input_vault_binary"></a> [vault_binary](#input_vault_binary) | Whether to use vault enterprise or not | `string` | `"vault"` | no |
| <a name="input_vault_name"></a> [vault_name](#input_vault_name) | The name of the vault cluster you wish to create | `string` | n/a | yes |
| <a name="input_vault_pki_secret_backend_role"></a> [vault_pki_secret_backend_role](#input_vault_pki_secret_backend_role) | The role to use in vault when generating the cert | `string` | `"pki"` | no |
| <a name="input_vault_version"></a> [vault_version](#input_vault_version) | The version of vault to install | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id) | The VPC where the cluster will be deployed | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_caller_identity"></a> [aws_caller_identity](#output_aws_caller_identity) | The caller identity object of the currently running Terraform user |
| <a name="output_iam"></a> [iam](#output_iam) | The IAM role used for the vault nodes |
| <a name="output_kms"></a> [kms](#output_kms) | All kms key objects created by the module |
| <a name="output_s3"></a> [s3](#output_s3) | The entire s3 bucket object for vault backups |
| <a name="output_security_group"></a> [security_group](#output_security_group) | All security group objects |
| <a name="output_subnets"></a> [subnets](#output_subnets) | The subnet objects for the subnets used in this module |
<!-- END_TF_DOCS -->
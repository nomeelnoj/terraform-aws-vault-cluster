<!-- BEGIN_TF_DOCS -->
<!-- THESE DOCS ARE GENERATED.  Update doc.md in the .github/docs directory to make changes.
Update this file with the following command from the root of the repo:
terraform-docs -c ./.github/docs/.terraform-docs.yml .
-->
# Terraform AWS Vault Cluster

This module allows relatively opinionated creation of either an Enterprise or OSS vault cluster in AWS.

Please note that due to the nature of Vault, additional configuration will be required after creation. All required information for setup can be found in this README or in the [docs](./docs) folder in this repository.

## Features

- Supports both OSS and Enterprise Vault
- Application Load Balancer
- Raft Integrated Storage
- Ephemeral instances -- data is stored on instances but all configuration occurs in `user_data` at boot. Health checks ensure that no more than 1 instance is replaced at a time on `user_data` change to avoid data loss before the cluster can self-replicate the data to the new node
- `user_data` stored in S3 file to show diffs in `terraform plan` for easier validation of changes; secrets are detected with `issensitive` and cut into a 8 char sha to show changes while avoiding exposure
- Cloudwatch logging for both operator and audit logs
- Logrotate since vault's included logrotate does not play well with cloudwatch
- Automated snapshots for OSS (with additional configuration from [./extras/base-config](./extras/base-config/README.md)

_**NOTE: Validation of server configurations occurs at boot, so additional configurations may cause boot issues. It is recommended that when creating the cluster or making significant changes that you log into the host and watch `/var/log/user-data.log`**_

## Configuration

Configuration examples can be found in the [examples](./examples) folder.

- [Basic Cluster](./examples/basic/vault_cluster.tf)
- [Full Configuration](./examples/full/vault_cluster.tf)

To configure if the cluster will be enterprise or OSS, you need only set two values:

```hcl
module "vault_cluster" {
  # ... removed for brevity
  vault_version = "1.15.4+ent-1" # The binary version determines enterprise or not

  enterprise_license = {
    bucket = "my-vault-enterprise-license-bucket"
    s3_key = "vault.hclic" # Optional, default
  }
}
```

If using enterprise, you will also need to make sure that the IAM role created by this module has access to pull the license from the bucket.

NOTE: The terraform provider for the enterprise license bucket MUST be set, even if you are not using enterprise. You can simply alias the provider to the same account and it wont be used at all. The module passes a data block for this bucket to make sure the bucket exists to try and avoid issues with license access that may occur during apply without being exposed during plan time.

This module assumes you will eventually use a Vault cluster to issue certs, and thus has a dependency on the Vault terraform provider.

To run the module if you do not have Vault available, run a local dev server and set `cert.generate_local  = true` in your module call:

```shell
vault server -dev
```

Update your `setup.tf` to point the Vault provider at your temporary vault cluster (it will not be used, but is needed to instantiate the provider).

```hcl
provider "vault" {
  address = "http://127.0.0.1:8200"
}
```

Finally, update your module call:

```hcl
module "vault_cluster" {
  # ... removed for brevity
  cert = {
    generate_local = true
  }
}
```

After the Vault cluster has booted in AWS and you have configured it below, you can follow the steps below for rotating to a Vault-issued certificate, even if the Vault cluster issuing is the one you just set up.

## Bootstrapping a new cluster

While it can create a circular dependency, you can use Vault's own certificate authority provider to issue self-signed certs for your Vault cluster(s).

If you do not already have a Vault server to use to generate the certs, the initial deployment will need to use self-signed certs that will need to be rotated carefully once you have a vault cluster to use for issuing the certs (yes, you can inception yourself and use the Vault cluster you create with this module to issue the certs for the Vault cluster you create with this module).

The initial cluster will be deployed with self-signed certs, with instructions for how to rotate to vault-issued certs found in [docs/rotating_vault_certificates.md](./docs/rotating_vault_certificates.md)

_**NOTE: If you already have a Vault cluster that can issue certificates, that is the recommended approach.**_

1. Make sure to set `cert.generate_local = true` in your module call
2. Update the `load_balancer.health_check_path` to `"/v1/sys/health?activecode=200&standbycode=200&sealedcode=200&uninitcode=200"` as this will prevent nodes from failing healthchecks and getting replaced while you are trying to configure the cluster.
3. Run the Terraform to deploy the cluster, and proceed with the docs below

### Building the Cluster

Whether you have a cluster for issuing certs or are creating your first Vault cluster, the initial setup steps are the same.

Once the vault cluster is up and running, SSM or SSH into one of the hosts and initialize vault:

```
aws ssm start-session start-session --target <instance-id>
sudo su root
vault operator init
```
Make a note of the root token and recovery keys and store them in the password manager of your choice. You will need them if you ever need to force unseal or recover Vault.

Now that the cluster has been initialized, it is time to add a base configuration.

### Certificate Management

If you started from scratch at the beginning and generated a temporary local cert, you may want to use the Vault you just created to create new certs for itself.

You will need to configure the PKI endpoint so that you can re-run the cluster setup with the proper certificate. Configuring a PKI is out of scope for this repo.

You will need to rotate certs once the PKI backend is configured.  To do so without data loss, follow the steps in [Rotating Vault Certificates](./docs/rotating_vault_certificates.md).

After the initial configuration and the cluster is running with a Vault cert, it will auto-rotate as long as the Terraform is re-run within 30 days of certificate expiration. If the certificate expires, new nodes will not be able to join the cluster, and the certs will have to be replaced using the same process used during initial setup as documented in [./docs/rotating_vault_certificates.md](./docs/rotating_vault_certificates.md).

### Base Config

The [base configuration example](./extras/base-config) is meant only for OSS and will enable the automated daily snapshots the module user_data configures when OSS is chosen as the vault version.

It is extremely bare, meant only for demonstration purposes, as much more configuration will be required to run a Vault cluster. Detailed configuration of Vault is out of scope for this repository.

## Accepted Values

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws_region](#input_aws_region) | The region to which you are deploying | `string` | `"us-east-1"` | no |
| <a name="input_cert"></a> [cert](#input_cert) | All configuration values for the SSL certs used by Vault and the load balancer | <pre>object({<br>    generate_local                = optional(bool, false)<br>    ttl                           = optional(string, "8760h")<br>    alt_names                     = optional(list(string))<br>    vault_pki_secret_backend_role = optional(string, "pki")<br>  })</pre> | `{}` | no |
| <a name="input_dns"></a> [dns](#input_dns) | All configuration values related to DNS | <pre>object({<br>    use_route53  = optional(bool, true)<br>    hosted_zone  = string<br>    hostname     = string<br>    private_zone = optional(bool, true)<br>  })</pre> | n/a | yes |
| <a name="input_enterprise_license"></a> [enterprise_license](#input_enterprise_license) | Config values for the Enterprise license. Consists of an S3 bucket and s3 key where the license file exists. | <pre>object({<br>    bucket_name = optional(string)<br>    s3_key      = optional(string)<br>  })</pre> | <pre>{<br>  "s3_key": "vault.hclic"<br>}</pre> | no |
| <a name="input_iam"></a> [iam](#input_iam) | A variable to contain all IAM information passed into the module | <pre>object({<br>    assume_role_policies = optional(map(object({<br>      sid    = optional(string)<br>      effect = optional(string, "Allow")<br>      principals = list(object({<br>        type        = string<br>        identifiers = list(string)<br>      }))<br>      actions = list(string)<br>      conditions = optional(list(object({<br>        test     = string<br>        variable = string<br>        values   = list(string)<br>      })), null)<br>    })), {})<br>    max_session_duration = optional(number, 3600)<br>    policy_statements = optional(map(object({<br>      sid         = optional(string)<br>      effect      = optional(string, "Allow")<br>      actions     = list(string)<br>      not_actions = optional(list(string))<br>      resources   = optional(list(string))<br>      conditions = optional(list(object({<br>        test     = string<br>        variable = string<br>        values   = list(string)<br>      })))<br>    })), {})<br>  })</pre> | `{}` | no |
| <a name="input_kms"></a> [kms](#input_kms) | All arguments related to KMS keys.  Module creates a key each for auto-unseal, cloudwatch, and s3 backups | <pre>object({<br>    admin_arns = list(string)<br>    policy_statements = optional(map(object({<br>      sid    = string<br>      effect = string<br>      principals = list(object({<br>        type        = string<br>        identifiers = list(string)<br>      }))<br>      actions = list(string)<br>      conditions = optional(list(object({<br>        test     = string<br>        variable = string<br>        values   = list(string)<br>      })), [])<br>    })), {})<br>  })</pre> | `null` | no |
| <a name="input_load_balancer"></a> [load_balancer](#input_load_balancer) | All configuration values for the load balancer. For uninitialized nodes, use /v1/sys/health?activecode=200&standbycode=200&sealedcode=200&uninitcode=200 for the health_check_path. | <pre>object({<br>    health_check_matcher          = optional(string, "200,429")<br>    ingress_cidrs                 = optional(list(string))<br>    ingress_security_groups       = optional(list(string))<br>    additional_lb_security_groups = optional(list(string), [])<br>    health_check_path             = optional(string, "/v1/sys/health")<br>  })</pre> | `{}` | no |
| <a name="input_log_retention"></a> [log_retention](#input_log_retention) | The log retention for vault server logs | `number` | `731` | no |
| <a name="input_s3"></a> [s3](#input_s3) | A map of all the various configuration values for the s3 bucket created to store backups. | <pre>object({<br>    bucket        = string<br>    force_destroy = optional(bool, false)<br>    sse           = optional(string, "aws:kms")<br>    policy_statements = optional(map(object({<br>      sid    = string<br>      effect = string<br>      principals = optional(list(object({<br>        type        = string<br>        identifiers = list(string)<br>      })))<br>      not_principals = optional(list(object({<br>        type        = string<br>        identifiers = list(string)<br>      })))<br>      actions       = optional(list(string))<br>      not_actions   = optional(list(string))<br>      resources     = optional(list(string), [])<br>      not_resources = optional(list(string))<br>      conditions = optional(list(object({<br>        test     = string<br>        variable = string<br>        values   = list(string)<br>      })))<br>    })), {})<br>    kms_policy_statements = optional(map(object({<br>      sid    = string<br>      effect = string<br>      principals = optional(list(object({<br>        type        = string<br>        identifiers = list(string)<br>      })))<br>      not_principals = optional(list(object({<br>        type        = string<br>        identifiers = list(string)<br>      })))<br>      actions       = optional(list(string))<br>      not_actions   = optional(list(string))<br>      resources     = optional(list(string), [])<br>      not_resources = optional(list(string))<br>      conditions = optional(list(object({<br>        test     = string<br>        variable = string<br>        values   = list(string)<br>      })))<br>    })), {})<br>  })</pre> | n/a | yes |
| <a name="input_server"></a> [server](#input_server) | All configuration values for the vault servers | <pre>object({<br>    ami_id                      = optional(string)<br>    arch                        = optional(string, "arm64")<br>    root_device_name            = optional(string)<br>    create_key_name             = optional(string)<br>    ssh_public_key              = optional(string)<br>    key_name                    = optional(string)<br>    instance_type               = optional(string, "m7g.large")<br>    node_count                  = optional(number, 3)<br>    ssh_ingress_cidrs           = optional(list(string), [])<br>    ssh_ingress_security_groups = optional(list(string), [])<br>  })</pre> | `{}` | no |
| <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids) | The list of subnet IDs to use when deploying vault | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input_tags) | A map of key value tags to apply to all AWS resources | `map(string)` | n/a | yes |
| <a name="input_vault_config"></a> [vault_config](#input_vault_config) | The vault config values to add to the userdata for populating /etc/vault/vault.hcl. | <pre>object({<br>    vault_name                    = string<br>    vault_version                 = string<br>    auto_join_tag_key             = optional(string)<br>    auto_join_tag_value           = optional(string, "server")<br>    disable_performance_standby   = optional(bool, true)<br>    ui                            = optional(bool, true)<br>    disable_mlock                 = optional(bool, true)<br>    disable_sealwrap              = optional(bool, true)<br>    additional_server_configs     = optional(string, "")<br>    additional_server_tcp_configs = optional(string, "")<br>    audit_log_path                = optional(string, "/opt/vault/vault-audit.log")<br>    operator_log_path             = optional(string, "/var/log/vault-operator.log")<br>  })</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id) | The VPC where the cluster will be deployed | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_caller_identity"></a> [aws_caller_identity](#output_aws_caller_identity) | The caller identity object of the currently running Terraform user |
| <a name="output_cert_data"></a> [cert_data](#output_cert_data) | The values of the certificate, helpful for when mTLS certs need to rotate across nodes.  See docs at docs/rotating_vault_certificates.md. |
| <a name="output_iam"></a> [iam](#output_iam) | The IAM role used for the vault nodes |
| <a name="output_kms"></a> [kms](#output_kms) | All kms key objects created by the module |
| <a name="output_s3"></a> [s3](#output_s3) | The entire s3 bucket object for vault backups |
| <a name="output_security_group"></a> [security_group](#output_security_group) | All security group objects |
| <a name="output_subnets"></a> [subnets](#output_subnets) | The subnet objects for the subnets used in this module |
<!-- END_TF_DOCS -->
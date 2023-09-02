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

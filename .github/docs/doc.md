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

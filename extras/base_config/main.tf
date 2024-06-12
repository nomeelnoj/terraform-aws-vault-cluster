# Assumes the aws auth backend is already configured
# If not, and it is created in this confir, make sure
# to remove the lifecycle precondition and update
# line 28 accordingly
data "vault_auth_backend" "aws" {
  path = "aws"
}

# The policy required for taking snapshots on a cadence
data "vault_policy_document" "snapshotter" {
  rule {
    path         = "/sys/storage/raft/snapshot"
    capabilities = ["read"]
  }
  rule {
    path         = "/sys/storage/raft/configuration"
    capabilities = ["list", "read"]
  }
}

resource "vault_policy" "snapshotter" {
  name   = "snapshotter"
  policy = data.vault_policy_document.snapshotter.hcl
}

# Creates the vault role used for snapshots
resource "vault_aws_auth_backend_role" "snapshotter" {
  backend                  = data.vault_auth_backend.aws.path
  role                     = "snapshotter"
  auth_type                = "iam"
  bound_iam_principal_arns = [var.snapshotter_role_arn]
  token_ttl                = 900
  token_max_ttl            = 1800
  token_policies           = [vault_policy.snapshotter.name]

  lifecycle {
    precondition {
      condition     = data.vault_auth_backend.aws != null
      error_message = "In order for this code to run, you must already have created the AWS auth vault backend."
    }
  }
}

# Modifies the raft autopilot configuration to clean up dead or
# unresponsive servers much more aggressively
resource "vault_raft_autopilot" "autopilot" {
  cleanup_dead_servers               = true
  dead_server_last_contact_threshold = "1m"
  last_contact_threshold             = "10s"
  max_trailing_logs                  = 15000
  min_quorum                         = 3
  server_stabilization_time          = "10s"
}

# Sets up the audit log file, which this module is set to log
# to cloudwatch once configured
resource "vault_audit" "file" {
  type        = "file"
  description = "File audit device"
  options = {
    path = "/var/log/vault-audit.log"
    mode = "0644"
  }
}

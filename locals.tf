locals {
  auto_join_tag_key = var.vault_config["auto_join_tag_key"] != null ? var.vault_config["auto_join_tag_key"] : var.vault_config["vault_name"]
  tags = merge(
    var.tags,
    {
      Name                      = var.vault_config["vault_name"]
      (local.auto_join_tag_key) = var.vault_config["auto_join_tag_value"]
    },
  )

  user_data = templatefile(
    "${path.module}/templates/user_data.sh.tpl",
    local.user_data_values
  )

  user_data_values = {
    disable_performance_standby   = lookup(var.vault_config, "disable_performance_standby", true)
    ui                            = lookup(var.vault_config, "ui", true)
    disable_mlock                 = lookup(var.vault_config, "disable_mlock", true)
    disable_sealwrap              = lookup(var.vault_config, "disable_sealwrap", true)
    additional_server_configs     = lookup(var.vault_config, "additional_server_configs", "")
    additional_server_tcp_configs = lookup(var.vault_config, "additional_server_tcp_configs", "")
    audit_log_path                = var.vault_config["audit_log_path"]
    operator_log_path             = var.vault_config["operator_log_path"]
    region                        = var.aws_region
    tag_key                       = local.auto_join_tag_key
    tag_value                     = var.vault_config["auto_join_tag_value"]

    vault_binary  = strcontains(var.vault_config["vault_version"], "ent") ? "vault-enterprise" : "vault"
    vault_version = var.vault_config["vault_version"]

    vault_enterprise_license_config = strcontains(
      var.vault_config["vault_version"], "ent"
    ) ? "license_path = \"/opt/vault/vault.hclic\"" : ""

    enterprise_download = !strcontains(
      var.vault_config["vault_version"], "ent"
    ) ? "" : <<EOT
aws s3 cp s3://${data.aws_s3_bucket.enterprise_license[0].bucket}/${var.enterprise_license["s3_key"]} /opt/vault/vault.hclic
# vault.hclic should be readable by the vault group only
chown root:vault /opt/vault/vault.hclic
chmod 0640 /opt/vault/vault.hclic
EOT

    snapshot_config = strcontains(
      var.vault_config["vault_version"], "ent"
    ) ? "" : <<EOT
cat <<-EOF > /etc/cron.daily/vault_snapshot
#!/bin/bash

TOKEN=\$(vault login -method=aws -field=token role=snapshotter)

export VAULT_TOKEN="\$${TOKEN}"

IMDS_TOKEN=\$( curl -Ss -H "X-aws-ec2-metadata-token-ttl-seconds: 30" -XPUT 169.254.169.254/latest/api/token )
INSTANCE_ID=\$( curl -Ss -H "X-aws-ec2-metadata-token: \$${IMDS_TOKEN}" 169.254.169.254/latest/meta-data/instance-id )

LEADER_ID=\$(vault operator raft list-peers | grep leader | awk '{print \$1}')

if [[ "\$${INSTANCE_ID}" == "\$${LEADER_ID}" ]]; then
  DATE=\$(date +%Y-%m-%d-%H-%M-%S)
  FILENAME="vault-snapshot-\$${DATE}Z.snap"
  vault operator raft snapshot save \$${FILENAME}
  aws s3 cp "\$${FILENAME}" "s3://${aws_s3_bucket.default.bucket}"
  rm "\$${FILENAME}"
fi
EOF
chmod +x /etc/cron.daily/vault_snapshot
EOT

    kms_key_arn     = aws_kms_key.default["auto_unseal"].arn
    leader_hostname = var.dns["hostname"]
    cert_key        = local.cert_key
    cert_chain      = local.cert_chain
    cert_pem        = local.cert_pem
    arch            = var.server["arch"]
    cloudwatch_agent_config = templatefile(
      "${path.module}/templates/cloudwatch_agent_config.json.tpl",
      {
        audit_log_path            = var.vault_config["audit_log_path"]
        operator_log_path         = var.vault_config["operator_log_path"]
        cloudwatch_log_group_name = aws_cloudwatch_log_group.default.name
        vault_name                = var.vault_config["vault_name"]
        environment               = lookup(var.tags, "Environment", var.vault_config["vault_name"])
      }
    )
    load_balancer_subnet_cidrs = jsonencode([for k, v in data.aws_subnet.lb_header_passthrough : v.cidr_block])
  }
}

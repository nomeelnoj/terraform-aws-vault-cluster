#!/usr/bin/env bash

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

IMDS_TOKEN=$( curl -Ss -H "X-aws-ec2-metadata-token-ttl-seconds: 30" -XPUT 169.254.169.254/latest/api/token )
INSTANCE_ID=$( curl -Ss -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" 169.254.169.254/latest/meta-data/instance-id )
LOCAL_IPV4=$( curl -Ss -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" 169.254.169.254/latest/meta-data/local-ipv4 )

# install packages with apt as it includes all the other
# helpful parts like systemd and makes it easier
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository -y "deb [arch=${arch}] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt update
# We use apt to install vault because it creates all the
# necessary directories with proper permissions, systemd configs,
# the vault user, etc.
# Be careful when running updates to ensure that the version you are installing
# is still there, as rolling nodes with a missing version will cause Vault data loss.

apt install -y \
  ${vault_binary}=${vault_version} \
  awscli \
  jq \
  unzip

echo "Configuring system time"
timedatectl set-timezone UTC

echo "Downloading the cloudwatch agent"

wget -q https://s3.${region}.amazonaws.com/amazoncloudwatch-agent-${region}/ubuntu/${arch}/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

echo "Adding cloudwatch config file"
cat << 'EOF' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
${cloudwatch_agent_config}
EOF

echo "Reloading the cloudwatch config"
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -s -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Ensuring audit log file exists"
touch ${audit_log_path}

echo "Ensuring operator log file exists"
touch ${operator_log_path}

echo "Ensuring vault owns and cloudwatch can read the audit log file"
chown vault:cwagent ${audit_log_path}
chown vault:cwagent ${operator_log_path}
chmod 0664 ${audit_log_path}
echo "restarting cloudwatch agent to load new configs"
systemctl restart amazon-cloudwatch-agent
chmod 0664 ${operator_log_path}

# removing any default installation files from /opt/vault/tls/
rm -rf /opt/vault/tls/*

# /opt/vault/tls directory should be readable by all users of the system
chmod 0755 /opt/vault/tls

# vault-key.pem should be readable by the vault group only
touch /opt/vault/tls/vault-key.pem /opt/vault/tls/vault-cert.pem /opt/vault/tls/vault-ca.pem
chown root:vault /opt/vault/tls/vault-key.pem
chmod 0644 /opt/vault/tls/vault-cert.pem /opt/vault/tls/vault-ca.pem
chmod 0640 /opt/vault/tls/vault-key.pem

echo "${cert_pem}" > /opt/vault/tls/vault-cert.pem

echo "${cert_chain}" > /opt/vault/tls/vault-ca.pem

echo "${cert_key}" > /opt/vault/tls/vault-key.pem

# if using the module for enterprise, we pull the enterprise license from S3 here
${enterprise_download}

# Setup graceful leaving
cat << EOF > /etc/rc0.d/vault-termination
systemctl stop vault
EOF

chmod +x /etc/rc0.d/vault-termination

cat << EOF > /etc/vault.d/vault.hcl
disable_performance_standby = ${disable_performance_standby}
ui               = ${ui}
disable_mlock    = ${disable_mlock}
disable_sealwrap = ${disable_sealwrap}
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "$INSTANCE_ID"
  retry_join {
    auto_join               = "provider=aws region=${region} tag_key=${tag_key} tag_value=${tag_value}"
    auto_join_scheme        = "https"
    leader_tls_servername   = "${leader_hostname}"
    leader_ca_cert_file     = "/opt/vault/tls/vault-ca.pem"
    leader_client_cert_file = "/opt/vault/tls/vault-cert.pem"
    leader_client_key_file  = "/opt/vault/tls/vault-key.pem"
  }
}

cluster_addr = "https://$LOCAL_IPV4:8201"
api_addr     = "https://${leader_hostname}"

listener "tcp" {
  address                          = "0.0.0.0:8200"
  tls_disable                      = false
  tls_cert_file                    = "/opt/vault/tls/vault-cert.pem"
  tls_key_file                     = "/opt/vault/tls/vault-key.pem"
  tls_client_ca_file               = "/opt/vault/tls/vault-ca.pem"
  x_forwarded_for_authorized_addrs = ${load_balancer_subnet_cidrs}
  ${indent(2, additional_server_tcp_configs)}
}
seal "awskms" {
  region     = "${region}"
  kms_key_id = "${kms_key_arn}"
}
telemetry {
  prometheus_retention_time = "60s"
  disable_hostname          = true
  statsd_address            = "127.0.0.1:8125"
}
log_format           = "json"
log_file             = "${operator_log_path}"
${additional_server_configs}
${vault_enterprise_license_config}
EOF

${snapshot_config}

# vault.hcl should be readable by the vault group only
echo "Setting permissions on vault.hcl config file"
chown root:root /etc/vault.d
chown root:vault /etc/vault.d/vault.hcl
chmod 640 /etc/vault.d/vault.hcl

echo "enabling vault"
systemctl enable vault
echo "starting or restarting vault"
systemctl restart vault

echo "setting up vault profile"
cat <<EOF > /etc/profile.d/vault.sh
export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_CACERT="/opt/vault/tls/vault-ca.pem"
EOF

echo "setting up vault env vars for all users"
cat <<EOF >> /etc/environment
VAULT_ADDR="https://127.0.0.1:8200"
VAULT_CACERT="/opt/vault/tls/vault-ca.pem"
EOF

echo "setting up logrotate for vault audit log"
cat <<EOF >> /etc/logrotate.d/vault-audit
${audit_log_path} {
  daily
  rotate 14
  compress
  copytruncate
  notifempty
  missingok
}
EOF

# We use logrotate because the built in vault rotator for operator logs does
# not play nice with cw agent bc of file permissions, and we dont want to give
# cwagent access to the vault group
echo "setting up logrotate for vault operator log"
cat <<EOF >> /etc/logrotate.d/vault-operator
${operator_log_path} {
  daily
  rotate 14
  compress
  copytruncate
  notifempty
  missingok
}
EOF

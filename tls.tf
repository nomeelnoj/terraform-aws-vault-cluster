locals {
  cert_pem   = try(vault_pki_secret_backend_cert.default[0].certificate, tls_locally_signed_cert.server[0].cert_pem)
  cert_chain = try(vault_pki_secret_backend_cert.default[0].issuing_ca, tls_self_signed_cert.ca[0].cert_pem)
  cert_key   = try(vault_pki_secret_backend_cert.default[0].private_key, tls_private_key.server[0].private_key_pem)
}

resource "vault_pki_secret_backend_cert" "default" {
  count       = var.generate_local_cert ? 0 : 1
  backend     = "pki"
  name        = var.vault_pki_secret_backend_role
  ttl         = var.ttl
  common_name = var.hostname
  alt_names   = var.alt_names
  ip_sans     = ["127.0.0.1"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "default" {
  private_key       = local.cert_key
  certificate_body  = local.cert_pem
  certificate_chain = local.cert_chain

  lifecycle {
    create_before_destroy = true
  }
  tags = merge(
    local.tags,
    {
      Name = var.hostname
    }
  )
}

# Generate a private key so you can create a CA cert with it.
resource "tls_private_key" "ca" {
  count     = var.generate_local_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a CA cert with the private key you just generated.
resource "tls_self_signed_cert" "ca" {
  count           = var.generate_local_cert ? 1 : 0
  private_key_pem = tls_private_key.ca[0].private_key_pem

  subject {
    common_name = var.hostname
  }

  validity_period_hours = 730 # 30 days

  allowed_uses = [
    "cert_signing",
    "crl_signing",
  ]

  is_ca_certificate = true

  # Uncomment to get cert on local machine
  provisioner "local-exec" {
    command = "echo '${tls_self_signed_cert.ca[0].cert_pem}' > ./vault-ca.pem"
  }
}

# Generate another private key. This one will be used
# To create the certs on your Vault nodes
resource "tls_private_key" "server" {
  count     = var.generate_local_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048

  # Uncomment to get key on local machine
  provisioner "local-exec" {
    command = "echo '${tls_private_key.server[0].private_key_pem}' > ./vault-key.pem"
  }
}

resource "tls_cert_request" "server" {
  count           = var.generate_local_cert ? 1 : 0
  private_key_pem = tls_private_key.server[0].private_key_pem

  subject {
    common_name = var.hostname
  }

  dns_names = [
    var.hostname,
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "server" {
  count              = var.generate_local_cert ? 1 : 0
  cert_request_pem   = tls_cert_request.server[0].cert_request_pem
  ca_private_key_pem = tls_private_key.ca[0].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca[0].cert_pem

  validity_period_hours = 730 # 30 days

  allowed_uses = [
    "client_auth",
    "digital_signature",
    "key_agreement",
    "key_encipherment",
    "server_auth",
  ]

  # Uncomment to get cert on local machine
  provisioner "local-exec" {
    command = "echo '${tls_locally_signed_cert.server[0].cert_pem}' > ./vault-crt.pem"
  }
}

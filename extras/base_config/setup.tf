provider "vault" {
  address         = "https://127.0.0.1:8281"
  skip_tls_verify = true
  ca_cert_file    = "vault-local.pem"
}

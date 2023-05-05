###TERRAFORM PROVIDER
provider "vault" {}

#NAMESPACE
resource "vault_namespace" "secret" {
  path = "on-prem"
}

###APP ROLE AUTHENTICATION
resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "tde-role" {
  #namespace = "${vault_namespace.secret.path}"
  backend   = vault_auth_backend.approle.path
  role_name = "tde-role"
  #token_policies = ["default", "tde-policy"]
  token_policies = ["tde-policy"]
}

data "vault_approle_auth_backend_role_id" "role" {
  #namespace = "${vault_namespace.secret.path}"
  backend   = vault_auth_backend.approle.path
  role_name = "tde-role"
}

output "role-id" {
  value = data.vault_approle_auth_backend_role_id.role.role_id
}

output "secret-id" {
  value     = vault_approle_auth_backend_role_secret_id.id.secret_id
  sensitive = true
}

resource "vault_approle_auth_backend_role_secret_id" "id" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.tde-role.role_name

  metadata = jsonencode(
    {
      "hello" = "world"
    }
  )
}

###APPROLE LOGIN
resource "vault_approle_auth_backend_login" "login" {
  #namespace = "${vault_namespace.secret.path}"
  backend   = vault_auth_backend.approle.path
  role_id   = vault_approle_auth_backend_role.tde-role.role_id
  secret_id = vault_approle_auth_backend_role_secret_id.id.secret_id
}

output "client_token" {
  value = vault_approle_auth_backend_login.login.client_token
}

output "client_token_metadata" {
  value = vault_approle_auth_backend_login.login.metadata
}

output "client_token_policies" {
  value = vault_approle_auth_backend_login.login.policies
}

###ACL POLICY
resource "vault_policy" "tde-policy" {
  name = "dev-team"

  policy = <<EOT
path "transit/keys/ekm-encryption-key" {
    capabilities = ["create", "read", "update", "delete"]
}

path "transit/keys" {
    capabilities = ["list"]
}

path "transit/encrypt/ekm-encryption-key" {
    capabilities = ["update"]
}

path "transit/decrypt/ekm-encryption-key" {
    capabilities = ["update"]
}

path "sys/license/status" {
    capabilities = ["read"]

}
EOT
}

###TRANSIT
resource "vault_mount" "transit" {
  namespace                 = vault_namespace.secret.path
  path                      = "transit/sqltde"
  type                      = "transit"
  description               = "sql tde"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 86400
}

resource "vault_transit_secret_cache_config" "cfg" {
  namespace = vault_namespace.secret.path
  backend   = vault_mount.transit.path
  size      = 500
}

resource "vault_transit_secret_backend_key" "key" {
  namespace          = vault_namespace.secret.path
  backend            = vault_mount.transit.path
  name               = "ekm-encryption-key"
  auto_rotate_period = 864000
  type               = "rsa-2048"
  #derived=true
  #convergent_encryption=true
}

###MISC
# resource "vault_mount" "secret" {
#   namespace = vault_namespace.secret.path
#   path      = "secrets"
#   type      = "kv"
#   options = {
#     version = "1"
#   }
# }

# resource "vault_generic_secret" "secret" {
#   namespace = vault_mount.secret.namespace
#   path      = "${vault_mount.secret.path}/secret"
#   data_json = jsonencode(
#     {
#       "ns" = "secret"
#     }
#   )
# }
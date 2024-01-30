#!/bin/bash

# logging functions
_log() {
  local type="$1"; shift
  # accept argument string or stdin
  local text="$*"; if [ "$#" -eq 0 ]; then text="$(cat)"; fi
  local dt; dt="$(date --rfc-3339=seconds)"
  printf '%s [%s] [bootstrap]: %s\n' "$dt" "$type" "$text"
}

_info() {
  _log INFO "$@"
}
_warn() {
  _log WARN "$@" >&2
}
_error() {
  _log ERROR "$@" >&2
  exit 1
}

_info "Starting bootstrap.sh"

########################################################################
#
# secrets
#
SECRETS=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString | jq -r .)

SSH_IMPORT_ID=$(echo $SECRETS | jq -r .ssh_import_id)

VAULT_LICENSE=$(echo $SECRETS | jq -r .vault_license)

GITREPO=$(echo $SECRETS | jq -r .gitrepo)
REPODIR=$(echo $SECRETS | jq -r .repodir)

CERT_DIR=$(echo $SECRETS  | jq -r .cert_dir)
WILDCARD_PRIVATE_KEY=$(echo $SECRETS  | jq -r .wildcard_private_key)
WILDCARD_CERT=$(echo $SECRETS  | jq -r .wildcard_cert)
CA_CERT=$(echo $SECRETS  | jq -r .ca_cert)

DOMAIN=$(echo $SECRETS  | jq -r .domain)

LDAP_USERS=$(echo $SECRETS  | jq -r .ldap_users)
LDAP_USER_VAULT_ADMIN=$(echo $SECRETS  | jq -r .ldap_user_vault_admin)

# ssh keys

if [ "$SSH_IMPORT_ID" != "" ]
then
  _info "Importing ssh keys for $SSH_IMPORT_ID"
  ssh-import-id $SSH_IMPORT_ID
fi

# Ubuntu docker privs
_info "Adding ubuntu user to docker group"
usermod -aG docker ubuntu

# auto-completions
_info "Configuring auto-completion for command commands"
cat <<EOF >> /root/.bashrc
complete -C /usr/bin/vault vault
complete -C /usr/bin/consul consul
complete -C /usr/bin/terraform terraform
complete -C /usr/bin/nomad nomad
complete -C /usr/bin/packer packer
EOF

# PKI
_info "Creating TLS certificate files"
mkdir -p $CERT_DIR/wildcard

if [ "$WILDCARD_PRIVATE_KEY" == "" ]
then
  _error "WILDCARD_PRIVATE_KEY is not set"
else
  _info "Writing WILDCARD_PRIVATE_KEY to $CERT_DIR/wildcard/privkey.pem"
  echo $WILDCARD_PRIVATE_KEY > $CERT_DIR/wildcard/privkey.pem
fi

if [ "$WILDCARD_CERT" == "" ]
then
  _error "WILDCARD_CERT is not set"
else
  _info "Writing WILDCARD_CERT to $CERT_DIR/wildcard/cert.pem"
  echo $WILDCARD_CERT > $CERT_DIR/wildcard/cert.pem
fi

if [ "$CA_CERT" == "" ]
then
  _error "CA_CERT is not set"
else
  _info "Writing CA_CERT to $CERT_DIR/wildcard/ca.pem"
  echo $CA_CERT > $CERT_DIR/wildcard/ca.pem
  _info "Writing CA_CERT to /usr/local/share/ca-certificates/demo-ca.pem"
  echo $CA_CERT > /usr/local/share/ca-certificates/demo-ca.pem
fi

_info "Writing wildcard private key and cert to $CERT_DIR/wildcard/privkey_cert.pem"
cat $CERT_DIR/wildcard/privkey.pem > $CERT_DIR/wildcard/privkey_cert.pem
cat $CERT_DIR/wildcard/cert.pem >> $CERT_DIR/wildcard/privkey_cert.pem

_info "Writing cert and ca cert (fullchain) to $CERT_DIR/wildcard/fullchain.pem"
cat $CERT_DIR/wildcard/cert.pem >> $CERT_DIR/wildcard/fullchain.pem
cat $CERT_DIR/wildcard/ca.pem >> $CERT_DIR/wildcard/fullchain.pem

_info "Writing private key, cert and ca cert (bundle) to $CERT_DIR/wildcard/bundle.pem"
cat $CERT_DIR/wildcard/privkey.pem > $CERT_DIR/wildcard/bundle.pem
cat $CERT_DIR/wildcard/cert.pem >> $CERT_DIR/wildcard/bundle.pem
cat $CERT_DIR/wildcard/ca.pem >> $CERT_DIR/wildcard/bundle.pem

_info "Running update-ca-certificates"
update-ca-certificates

# Vault
_info "Creating directories for Vault to run in docker"
mkdir -p \
  /data/vault/data \
  /data/vault/conf \
  /data/vault/audit \
  /data/vault/plugins \
  /data/vault/license

if [ "$VAULT_LICENSE" == "" ]
then
  _error "VAULT_LICENSE is not set"
else
  _info "Writing VAULT_LICENSE to /data/vault/license/vault.hclic"
  echo $VAULT_LICENSE > /data/vault/license/vault.hclic
fi

if [ "$DOMAIN" == "" ]
then
  _error "DOMAIN is not set"
fi

_info "Writing Vault config to /data/vault/conf/vault.hcl"
cat <<EOF > /data/vault/conf/vault.hcl
# raft storage
storage "raft" {
  path    = "/vault/data"
  node_id = "node_1"

 retry_join {
    leader_api_addr = "https://vault.$DOMAIN:8200"
    leader_ca_cert_file = "/run/secrets/wildcard_ca_cert"
    tls_cert_file = "/run/secrets/wildcard_cert"
    tls_key_file = "/run/secrets/wildcard_privkey"
  }
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/run/secrets/wildcard_fullchain"
  tls_key_file  = "/run/secrets/wildcard_privkey"
}

api_addr     = "https://vault.$DOMAIN:8200"
cluster_addr = "https://vault.$DOMAIN:8201"

cluster_name = "vault"
EOF

_info "Setting owner/group for /data/vault"
chown -R 100:1000 /data/vault

# Docker
_info "Enable and start docker"
sudo systemctl enable docker && \
sudo systemctl start docker

_info "Finished bootstrap.sh"

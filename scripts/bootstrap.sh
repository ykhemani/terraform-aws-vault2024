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
  cat <<EOF > $CERT_DIR/wildcard/privkey.pem
$WILDCARD_PRIVATE_KEY
EOF
fi

if [ "$WILDCARD_CERT" == "" ]
then
  _error "WILDCARD_CERT is not set"
else
  _info "Writing WILDCARD_CERT to $CERT_DIR/wildcard/cert.pem"
  cat <<EOF > $CERT_DIR/wildcard/cert.pem
$WILDCARD_CERT
EOF
fi

if [ "$CA_CERT" == "" ]
then
  _error "CA_CERT is not set"
else
  _info "Writing CA_CERT to $CERT_DIR/wildcard/ca.pem"
  cat <<EOF > $CERT_DIR/wildcard/ca.pem
$CA_CERT
EOF

  _info "Copying $CERT_DIR/wildcard/ca.pem to /usr/local/share/ca-certificates/demo-ca.pem"
  cp $CERT_DIR/wildcard/ca.pem /usr/local/share/ca-certificates/demo-ca.pem
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

# Write Vault environment file
_info "Writing Vault environment file ~/venv/venv"
mkdir -p ~/venv && \
  cd ~/venv
cat <<EOF > ~/venv/venv
export VAULT_ADDR=https://vault.$DOMAIN:8200
export VAULT_SKIP_VERIFY=true
export VAULT_TOKEN=\$(cat ~/venv/vault-init.json | jq -r .root_token)
export VAULT_UNSEAL=\$(cat ~/venv/vault-init.json | jq -r .unseal_keys_b64[])

export DOMAIN=$DOMAIN

export CERT_DIR=$CERT_DIR
export CA_CERT=$CERT_DIR/wildcard/ca.pem

# ldap auth
export LDAP_AUTH_PATH=ldap
export LDAP_USER_VAULT_ADMIN=$LDAP_USER_VAULT_ADMIN
# userpass auth
export USERPASS_AUTH_PATH=userpass

# approle auth for web app
export APPROLE_PATH=approle
export WEB_ROLE=web-role
export WEB_POLICY=web-policy

# pki
export ROOT_CA_NAME=vault-ca-root
export INTERMEDIATE_CA_NAME=vault-ca-intermediate
export VAULT_CERT_DOMAIN=demo.$DOMAIN
export VAULT_CERT_DIR="$CERT_DIR/demo.$DOMAIN"
export IMPORTED_CA_NAME=vault-ca-imported

# mysql
export MYSQL_HOST=mysql.$DOMAIN
export MYSQL_PORT=3306
export MYSQL_DB_NAME=demodb
export MYSQL_DB_TABLE=pii

export MYSQL_ROOT_USERNAME=root
export MYSQL_ROOT_PASSWORD=p@ssw0rD

export MYSQL_VAULT_USERNAME=vault
export MYSQL_VAULT_PASSWORD=van1tPassw#rd

export MYSQL_STATIC_USERNAME=demouser
export MYSQL_STATIC_PASSWORD=d3mopossw@rd

export MYSQL_PATH=mysql-demo
export MYSQL_ROLE=mysql-web-role

# mongodb
export MONGODB_PATH=mongodb-demo
export MONGODB_ROLE=mongodb-demo-role
export MONGODB_HOST=mongodb.$DOMAIN
export MONGODB_PORT=27017
export MONGODB_DB_NAME=admin
export MONGODB_ROOT_USERNAME=root
export MONGODB_ROOT_PASSWORD=p2sSwOrd
export MONGODB_URL=mongodb.$DOMAIN:27017/admin?tls=true

# mongo-gui
MONGO_GUI_PORT=3001

export KV_PATH=kv

export KV_MYSQL_PATH=mysql-web

export TRANSIT_PATH=transit
export TRANSIT_KEY=web-demo-key
export TRANSIT_ENCRYPT_POLICY=demo-encrypt
export TRANSIT_DECRYPT_POLICY=demo-decrypt

export TRANSFORM_FPE_PATH=transform-fpe
export TRANSFORM_FPE_ROLE=transform-fpe-demo

export TRANSFORM_TOKENIZATION_PATH=transform-tokenization
export TRANSFORM_TOKENIZATION_ROLE=transform-tokeization-demo

export SSH_PATH=ssh-client-signer

export VAULT_AGENT_PATH=/data/vault-agent
export TOKEN_PATH=/data/tokens

EOF

_info "Source Vault environment file ~/venv/venv"
. ~/venv/venv

_info "Source Vault environment file ~/venv/venv in .bashrc"
cat <<EOF >> ~/.bashrc

if [ -f ~/venv/venv ]
then
  . ~/venv/venv
fi

EOF

_info "Add hosts entries"
echo "127.0.0.1 vault.$DOMAIN mysql.$DOMAIN mongodb.$DOMAIN mongo-ui.$DOMAIN postgres.$DOMAIN openldap.$DOMAIN ldap.$DOMAIN web.$VAULT_CERT_DOMAIN" >> /etc/hosts

# placeholder values
export TRANSIT_ENCRYPT_TOKEN="TRANSIT_ENCRYPT_TOKEN"
export TRANSIT_DECRYPT_TOKEN="TRANSIT_DECRYPT_TOKEN"

_info "Create docker-compose.yaml"
mkdir -p \
  /data/docker-demo-stack

cat <<EOF > /data/docker-demo-stack/docker-compose.yaml
version: '3.9'

services:
  vault:
    container_name: vault
    hostname: vault.$DOMAIN
    image: hashicorp/vault-enterprise:1.15.4-ent
    restart: unless-stopped
    ports:
      - 8200:8200
      - 8201:8201
    volumes:
      - /data/vault/data:/vault/data
      - /data/vault/conf:/vault/conf
      - /data/vault/audit:/vault/audit
      - /data/vault/snapshots:/vault/snapshots
      - /data/vault/plugins:/vault/plugins
    environment:
      - VAULT_ADDR=https://vault.$DOMAIN:8200
      - VAULT_API_ADDR=https://vault.$DOMAIN:8200
      - VAULT_CLUSTER_ADDR=https://vault.$DOMAIN:8201
      - VAULT_SKIP_VERIFY=true
      - VAULT_DISABLE_MLOCK=true
      - SKIP_SETCAP=true
      - VAULT_UI=true
      - VAULT_LICENSE_PATH=/run/secrets/vault_license
    command: vault server -config=/vault/conf/vault.hcl
    secrets:
      - wildcard_privkey
      - wildcard_cert
      - wildcard_ca_cert
      - wildcard_fullchain
      - vault_license

  mysql:
    container_name: mysql
    hostname: mysql.$DOMAIN
    image: mysql:5.7
    restart: unless-stopped
    volumes:
      - /data/mysql/etc/my.cnf:/etc/my.cnf
      - /data/mysql/var/lib/mysql:/var/lib/mysql
      - /data/mysql/dump:/dump
    ports:
      - 3306:3306
    environment:
      - MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root_password
    secrets:
      - mysql_root_password

  mongodb:
    container_name: mongodb
    hostname: mongodb.$DOMAIN
    image: mongo:7.0.5
    restart: unless-stopped
    volumes:
      - /data/mongodb/data:/data/db
    ports:
      - 27017:27017
    environment:
      MONGO_INITDB_DATABASE: $MONGO_INITDB_DATABASE
      MONGO_INITDB_ROOT_USERNAME_FILE: /run/secrets/mongodb_root_username
      MONGO_INITDB_ROOT_PASSWORD_FILE: /run/secrets/mongodb_root_password
    command: ["--bind_ip", "0.0.0.0", "--tlsMode", "requireTLS", "--tlsAllowConnectionsWithoutCertificates", "--tlsCertificateKeyFile", "/run/secrets/wildcard_key_and_cert", "--tlsCAFile", "/run/secrets/wildcard_ca_cert"]
    secrets:
      - wildcard_key_and_cert
      - wildcard_ca_cert
      - mongodb_root_username
      - mongodb_root_password

  mongo-gui:
    container_name: mongo-gui
    image: mongo-gui:latest
    restart: unless-stopped
    ports:
      - $MONGO_GUI_PORT:$MONGO_GUI_PORT
    environment:
      - PORT=$MONGO_GUI_PORT
      - CA_CERT=/run/secrets/wildcard_ca_cert
      - CERT=/run/secrets/wildcard_cert
      - PRIVKEY=/run/secrets/wildcard_privkey
      - URL_FILE=/run/secrets/mongodb_url
    secrets:
      - wildcard_privkey
      - wildcard_cert
      - wildcard_ca_cert
      - mongodb_url

  web:
    container_name: web
    image: php:8.1.1-apache-mysqli
    restart: unless-stopped
    volumes:
      - /data/php/conf/default-ssl.conf:/etc/apache2/sites-enabled/default-ssl.conf
      - /data/php/conf/socache_shmcb.load:/etc/apache2/mods-enabled/socache_shmcb.load
      - /data/php/conf/ssl.load:/etc/apache2/mods-enabled/ssl.load
      - /data/php/conf/ssl.conf:/etc/apache2/mods-enabled/ssl.conf
      - /data/web:/var/www/html
    ports:
      - 80:80
      - 443:443
    environment:
      - TRANSIT_ENCRYPT_TOKEN=\$TRANSIT_ENCRYPT_TOKEN
      - TRANSIT_DECRYPT_TOKEN=\$TRANSIT_DECRYPT_TOKEN
      - MYSQL_STATIC_USERNAME=\$MYSQL_STATIC_USERNAME
      - MYSQL_STATIC_PASSWORD=\$MYSQL_STATIC_PASSWORD
      - MYSQL_DB_NAME=\$MYSQL_DB_NAME
      - MYSQL_DB_TABLE=\$MYSQL_DB_TABLE
      - MYSQL_HOST=\$MYSQL_HOST
      - VAULT_ADDR=https://vault.$DOMAIN:8200
      - WEB_SERVER_URL=https://web.$VAULT_CERT_DOMAIN/
      - MONGO_GUI_URL=https://mongo-ui.$DOMAIN:$MONGO_GUI_PORT
    secrets:
      - web_pki_privkey
      - web_pki_cert

  openldap:
    container_name: openldap
    hostname: openldap.$DOMAIN
    image: bitnami/openldap:2.6.6
    restart: unless-stopped
    volumes:
      - /data/openldap:/bitnami/openldap
    ports:
      - 636:636
      - 389:389
    environment:
      - LDAP_ADMIN_USERNAME=admin
      - LDAP_ADMIN_PASSWORD=password
      - LDAP_USERS=$LDAP_USERS
      - LDAP_PASSWORDS=$LDAP_USERS
      - LDAP_ROOT=dc=example,dc=com
      - LDAP_USER_DC=users
      - LDAP_GROUP=engineers
      - LDAP_ADMIN_DN=cn=admin,dc=example,dc=com
      - LDAP_PORT_NUMBER=389
      - LDAP_ENABLE_TLS=yes
      - LDAP_REQUIRE_TLS=no
      - LDAP_LDAPS_PORT_NUMBER=636
      - LDAP_TLS_KEY_FILE=/run/secrets/wildcard_privkey
      - LDAP_TLS_CERT_FILE=/run/secrets/wildcard_cert
      - LDAP_TLS_CA_FILE=/run/secrets/wildcard_ca_cert
    secrets:
      - wildcard_privkey
      - wildcard_cert
      - wildcard_ca_cert

  # ldap-ui:
  #   container_name: ldap-ui
  #   hostname: ldap-ui.example.com
  #   image: dnknth/ldap-ui:latest
  #   restart: unless-stopped
  #   ports:
  #     - 5000:5000

secrets:
  # wildcard certs
  wildcard_privkey:
    file: /data/certs/wildcard/privkey.pem
  wildcard_cert:
    file: /data/certs/wildcard/fullchain.pem
  wildcard_ca_cert:
    file: /data/certs/wildcard/ca.pem
  wildcard_fullchain:
    file: /data/certs/wildcard/fullchain.pem
  wildcard_key_and_cert:
    file: /data/certs/wildcard/privkey_cert.pem
  wildcard_bundle:
    file: /data/certs/wildcard/bundle.pem

  # licensing
  vault_license:
    file: /data/vault/license/vault.hclic

  # mysql
  mysql_root_password:
    file: /data/mysql/secrets/mysql_root_password

  # mongodb
  mongodb_root_username:
    file: /data/mongodb/secrets/mongodb_root_username
  mongodb_root_password:
    file: /data/mongodb/secrets/mongodb_root_password
  mongodb_url:
    file: /data/mongodb/secrets/mongodb_url

  # web app dynamic pki cert
  web_pki_privkey:
    file: $CERT_DIR/$VAULT_CERT_DOMAIN/privkey.pem
  web_pki_cert:
    file: $CERT_DIR/$VAULT_CERT_DOMAIN/fullchain.pem
EOF

_info "Enable and start docker"
sudo systemctl enable docker && \
sudo systemctl start docker

_info "Starting Vault"
cd /data/docker-demo-stack && \
  docker-compose up -d vault

_info "Sleep 10"
sleep 10

_info "Initialize Vault"
vault operator init \
  -format=json \
  -key-shares=1 \
  -key-threshold=1 \
  | tee ~/venv/vault-init.json

_info "Source ~/venv/venv"
. ~/venv/venv

_info "Unseal Vault"
vault operator unseal $VAULT_UNSEAL

_info "Configure Vault audit logs"
vault audit enable file \
  file_path=/vault/audit/audit.log && \
  vault audit enable -path=raw file \
    file_path=/vault/audit/raw.log log_raw=true

vault audit list -detailed

_info "Configure AppRole Auth"
vault auth enable -path=$APPROLE_PATH approle

_info "Create AppRole role for web app"
vault write auth/$APPROLE_PATH/role/$WEB_ROLE \
  secret_id_ttl=0 \
  token_num_uses=0 \
  token_ttl=720h \
  token_max_ttl=720h \
  secret_id_num_uses=0 \
  token_policies=$WEB_POLICY

_info "Finished bootstrap.sh"

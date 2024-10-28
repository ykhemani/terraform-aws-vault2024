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

NAMESPACES=$(echo $SECRETS | jq -r .namespaces)

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

# supress warning in new version of Vault
_info "set DBUS_SESSION_BUS_ADDRESS=/dev/null"
cat <<EOF >> /root/.bashrc
export DBUS_SESSION_BUS_ADDRESS=/dev/null
EOF

export DBUS_SESSION_BUS_ADDRESS=/dev/null

# CoreDNS
_info "Download coredns"
cd /tmp && \
  wget https://github.com/coredns/coredns/releases/download/v1.11.3/coredns_1.11.3_linux_amd64.tgz && \
  tar xvfz coredns_1.11.3_linux_amd64.tgz && \
  mv coredns /usr/bin/coredns

_info "Create directories for coredns"
mkdir -p /etc/coredns /var/lib/coredns

_info "Add user coredns"
useradd coredns

_info "Set ownership of /var/lib/coredns to user coredns"
chown coredns:coredns /var/lib/coredns

_info "Create /etc/coredns/Corefile"
cat <<EOF > /etc/coredns/Corefile
example.com:53 {
  log
  errors
  file db.example.com
}

.:53 {
  forward . 1.1.1.1 1.0.0.1
  log
}
EOF

_info "Create coredns systemd unit file"
cat <<EOF > /etc/systemd/system/coredns.service
[Unit]
Description=CoreDNS DNS server
Documentation=https://coredns.io
After=network.target

[Service]
PermissionsStartOnly=true
LimitNOFILE=1048576
LimitNPROC=512
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
User=coredns
WorkingDirectory=/var/lib/coredns
ExecStart=/usr/bin/coredns -conf=/etc/coredns/Corefile
ExecReload=/bin/kill -SIGUSR1 \$MAINPID
Restart=on-failure
StandardOutput=append:/var/log/coredns.log
StandardError=append:/var/log/coredns.err.log


[Install]
WantedBy=multi-user.target
EOF

_info "Create Corefile"
cat <<EOF > /etc/coredns/Corefile
example.com:53 {
  log
  errors
  file db.example.com
}

.:53 {
  forward . 1.1.1.1 1.0.0.1
  log
}
EOF

_info "Create /var/lib/coredns/db.example.com"

export PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
export SERIAL="$(date +%Y%m%d)01"

cat <<EOF > /var/lib/coredns/db.example.com
\$ORIGIN example.com.  ; designates the start of this zone file in the namespace
\$TTL 1h               ; default expiration time
@                 IN  SOA     ns.example.com. yash.example.com. (
                                  $SERIAL     ; Serial
                                  1h             ; Refresh
                                  1h             ; Retry
                                  1d             ; Expire
                                  1h)            ; Minimum TTL
@                 IN  A       $PUBLIC_IP
@                 IN  NS      ns.example.com.
ns                IN  CNAME   @
vault             IN  CNAME   @
mysql             IN  CNAME   @
postgres          IN  CNAME   @
mongodb           IN  CNAME   @
mongo-ui          IN  CNAME   @
ldap              IN  CNAME   @
openldap          IN  CNAME   @
web.demo          IN  CNAME   @
EOF

_info "Stop and disable systemd-resolved"
systemctl stop systemd-resolved
systemctl disable systemd-resolved

_info "Replace resolv.conf"
mv /etc/resolv.conf /etc/resolv.conf-
echo "nameserver 127.0.0.1" > /etc/resolv.conf

_info "Enable and start coredns"
systemctl enable coredns.service
systemctl start coredns.service

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

if [ "$VAULT_CONTAINER_IMAGE" == "" ]
then
  _error "VAULT_CONTAINER_IMAGE is not set"
fi

_info "Writing Vault config to /data/vault/conf/vault.hcl"
cat <<EOF > /data/vault/conf/vault.hcl
# raft storage
storage "raft" {
  path    = "/vault/data"
  node_id = "node_1"

  retry_join {
    leader_api_addr     = "https://vault.$DOMAIN:8200"
    leader_ca_cert_file = "/run/secrets/wildcard_ca_cert"
    tls_cert_file       = "/run/secrets/wildcard_cert"
    tls_key_file        = "/run/secrets/wildcard_privkey"
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

seal "awskms" {
  kms_key_id = "$KMS_KEY_ID"
}

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
    image: $VAULT_CONTAINER_IMAGE
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
      - GITREPO=$GITREPO
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

  ldap-ui:
    container_name: ldap-ui
    hostname: ldap-ui.example.com
    image: dnknth/ldap-ui:latest
    restart: unless-stopped
    ports:
      - 5000:5000
    environment:
      - LDAP_URL=ldaps://openldap.example.com
      - USE_TLS=true
      - INSECURE_TLS=true
      - BASE_DN=dc=example,dc=com
      - BIND_DN=cn=admin,dc=example,dc=com
      - BIND_PASSWORD=password

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

if [ $STOP_AFTER_STARTING_VAULT == "1" ]
then
  _info "docker ps:"
  docker ps

  _info "docker logs vault"
  docker logs vault

  _info "Vault Status"
  curl -sk $VAULT_ADDR/v1/sys/health | jq

  _info "Exiting bootstrap."
  exit 0
fi

_info "Sleep 30"
sleep 30

_info "Vault Status"
curl -sk $VAULT_ADDR/v1/sys/health | jq

_info "Initialize Vault"
vault operator init \
  -format=json \
  -recovery-shares=1 \
  -recovery-threshold=1 \
  | tee ~/venv/vault-init.json

_info "Source ~/venv/venv"
. ~/venv/venv

# not needed for kms seal
# _info "Unseal Vault"
# vault operator unseal $VAULT_UNSEAL

# Audit Logs
_info "Configure Vault audit logs"
vault audit enable file \
  file_path=/vault/audit/audit.log && \
  vault audit enable -path=raw file \
    file_path=/vault/audit/raw.log log_raw=true

vault audit list -detailed

# AppRole
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

# KV
_info "Enable KV secrets engine"
vault secrets disable $KV_PATH
vault secrets enable -path $KV_PATH kv-v2

_info "Write kv secret to $KV_PATH/engineering/app1"
vault kv put $KV_PATH/engineering/app1 user=$(uuidgen) pass=$(uuidgen)

# SSH
_info "Enable ssh secrets engine"
vault secrets enable -path $SSH_PATH ssh

# Transit Secrets Engine
_info "Enable transit secret engine"
vault secrets disable $TRANSIT_PATH
vault secrets enable -path $TRANSIT_PATH transit

_info "Create transit encryption key"
vault write -f $TRANSIT_PATH/keys/$TRANSIT_KEY

_info "Create directory $TOKEN_PATH for writing Vault tokens related to transit operations"
mkdir -p $TOKEN_PATH

_info "Generate Vault token with decrypt policy"
vault token create -format=json -ttl=720h -policy=$TRANSIT_DECRYPT_POLICY -orphan | tee $TOKEN_PATH/$TRANSIT_DECRYPT_POLICY-token.json
_info "Set TRANSIT_DECRYPT_TOKEN"
export TRANSIT_DECRYPT_TOKEN=$(cat $TOKEN_PATH/$TRANSIT_DECRYPT_POLICY-token.json | jq -r .auth.client_token)

_info "Generate Vault token with encrypt policy"
vault token create -format=json -ttl=720h -policy=$TRANSIT_ENCRYPT_POLICY -orphan | tee $TOKEN_PATH/$TRANSIT_ENCRYPT_POLICY-token.json
_info "Set TRANSIT_ENCRYPT_TOKEN"
export TRANSIT_ENCRYPT_TOKEN=$(cat $TOKEN_PATH/$TRANSIT_ENCRYPT_POLICY-token.json | jq -r .auth.client_token)

# Transform Secret Engine (FPE)
_info "Enable and configure transform secret engine for FPE"
vault secrets disable $TRANSFORM_FPE_PATH
vault secrets enable -path $TRANSFORM_FPE_PATH transform

vault write $TRANSFORM_FPE_PATH/transformations/fpe/card-number \
  template="builtin/creditcardnumber" \
  tweak_source=internal \
  allowed_roles=$TRANSFORM_FPE_ROLE

 vault write $TRANSFORM_FPE_PATH/template/us-ssn-tmpl \
   type=regex \
   pattern='(?:SSN[: ]?|ssn[: ]?)?(\d{3})[- ]?(\d{2})[- ]?(\d{4})' \
   encode_format='$1-$2-$3' \
   decode_formats=space-separated='$1 $2 $3' \
   decode_formats=last-four='*** ** $3' \
   alphabet=builtin/numeric

vault write $TRANSFORM_FPE_PATH/transformations/fpe/us-ssn \
  template=us-ssn-tmpl \
  tweak_source=internal \
  allowed_roles='*'

vault write $TRANSFORM_FPE_PATH/role/$TRANSFORM_FPE_ROLE transformations=card-number,us-ssn

# Transform Secret Engine (Tokenization)
_info "Enable and configure transform secret engine for tokenization"
vault secrets disable $TRANSFORM_TOKENIZATION_PATH
vault secrets enable -path $TRANSFORM_TOKENIZATION_PATH transform

vault write $TRANSFORM_TOKENIZATION_PATH/role/$TRANSFORM_TOKENIZATION_ROLE transformations=credit-card

vault write $TRANSFORM_TOKENIZATION_PATH/transformations/tokenization/credit-card \
  allowed_roles=$TRANSFORM_TOKENIZATION_ROLE

# PKI
_info "Enable and configure PKI secret engines"

_info "Make directory $VAULT_CERT_DIR for PKI certificates"
mkdir -p $VAULT_CERT_DIR

# Root CA
_info "Enable Vault pki secret engine for root ca"
vault secrets enable -path $ROOT_CA_NAME pki

_info "Configure max ttl for root ca"
vault secrets tune -max-lease-ttl=87600h $ROOT_CA_NAME

_info "Generate root ca"
vault write -format=json $ROOT_CA_NAME/root/generate/internal \
  common_name="ca.$VAULT_CERT_DOMAIN" ttl=87600h \
  issuer_name="root-2023" | tee \
  >(jq -r .data.certificate > $VAULT_CERT_DIR/vault-ca-root.pem)

_info "Configure CA and CRL URLs for root ca"
vault write $ROOT_CA_NAME/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/$ROOT_CA_NAME/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/$ROOT_CA_NAME/crl"

# Intermediate CA
_info "Enable pki secret engine for intermediate ca"
vault secrets enable -path $INTERMEDIATE_CA_NAME pki

_info "Configure max ttl for intermediate ca"
vault secrets tune -max-lease-ttl=43800h $INTERMEDIATE_CA_NAME

_info "Configure CA and CRL URLs for intermediate ca"
vault write $INTERMEDIATE_CA_NAME/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/$INTERMEDIATE_CA_NAME/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/$INTERMEDIATE_CA_NAME/crl"

_info "Generate CSR and intermediate ca, will be signed by root ca"
vault write -format=json \
  $INTERMEDIATE_CA_NAME/intermediate/generate/internal \
  common_name="$VAULT_CERT_DOMAIN Intermediate Authority" \
  issuer_name="demo-seva-cafe-intermediate-2023" | tee \
  >(jq -r .data.csr > $VAULT_CERT_DIR/vault-ca-intermediate.csr)

_info "Sign intermediate ca csr using root ca"
vault write -format=json \
  $ROOT_CA_NAME/root/sign-intermediate \
  issuer_ref="root-2023" \
  csr=@$VAULT_CERT_DIR/vault-ca-intermediate.csr \
  common_name="$VAULT_CERT_DOMAIN Intermediate Authority" ttl=43800h | tee \
  >(jq -r .data.certificate > $VAULT_CERT_DIR/vault-ca-intermediate.pem)

_info "Set intermediate ca as signed"
vault write $INTERMEDIATE_CA_NAME/intermediate/set-signed \
  certificate=@$VAULT_CERT_DIR/vault-ca-intermediate.pem

_info "Create role for issuing certs in intermediate ca"
vault write $INTERMEDIATE_CA_NAME/roles/$VAULT_CERT_DOMAIN \
  allowed_domains="$VAULT_CERT_DOMAIN" \
  allow_subdomains="true" \
  ttl="1h" \
  max_ttl="24h" \
  generate_lease=true

# Imported CA
_info "Enable pki secret engine for imported ca"
vault secrets enable -path=$IMPORTED_CA_NAME pki

_info "Configure max ttl for imported ca"
vault secrets tune -max-lease-ttl=87600h $IMPORTED_CA_NAME

_info "Configure CA and CRL URLs for imported ca"
vault write $IMPORTED_CA_NAME/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/$IMPORTED_CA_NAME/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/$IMPORTED_CA_NAME/crl"

_info "Import PEM bundle into imported ca"
vault write -format=json $IMPORTED_CA_NAME/config/ca pem_bundle=@$CERT_DIR/wildcard/bundle.pem

_info "Create role for issuing certs in imported ca"
vault write $IMPORTED_CA_NAME/roles/$VAULT_CERT_DOMAIN \
  allowed_domains="$VAULT_CERT_DOMAIN" \
  allow_subdomains="true" \
  ttl="1h" \
  max_ttl="24h" \
  generate_lease=true

# clone mongo-gui repo
_info "Cloning mongo-gui repo"
cd /data && \
  git clone https://github.com/ykhemani/mongo-gui.git

_info "Build mongo-gui image"
cd /data/mongo-gui && \
  docker build -t mongo-gui:latest .

_info "Build web image"
cd /data/$REPODIR/php && \
  docker build -t php:8.1.1-apache-mysqli .

_info "Copy php config to /data/php/conf"
mkdir -p /data/php/conf && \
  cd /data/$REPODIR/php/conf && \
  cp * /data/php/conf/ && \
  cd /data

_info "Make directories for mysql, mongodb, openldap, and Vault minted PKI certificates"
mkdir -p \
  /data/mysql/etc \
  /data/mysql/var/lib/mysql \
  /data/mysql/dump \
  /data/mysql/secrets \
  /data/mongodb/secrets \
  /data/mongodb/data \
  /data/openldap \
  /data/php/conf \
  $CERT_DIR/web.$VAULT_CERT_DOMAIN

_info "Set owner for openldap directory"
chown 1001 /data/openldap

_info "Add TLS_CACERT to host LDAP config"
cat <<EOF >> /etc/ldap/ldap.conf
TLS_CACERT      $CERT_DIR/wildcard/ca.pem
EOF

_info "Create mysql config file"
touch /data/mysql/etc/my.cnf

_info "Write mysql root password"
echo $MYSQL_ROOT_PASSWORD > /data/mysql/secrets/mysql_root_password

_info "Write mongo secrets: root user, root password, mongo url"
echo $MONGODB_ROOT_USERNAME > /data/mongodb/secrets/mongodb_root_username
echo $MONGODB_ROOT_PASSWORD > /data/mongodb/secrets/mongodb_root_password
echo "mongodb://$MONGODB_ROOT_USERNAME:$MONGODB_ROOT_PASSWORD@mongodb.$DOMAIN:$MONGODB_PORT/$MONGODB_DB_NAME?tls=true" > /data/mongodb/secrets/mongodb_url

_info "Replace VAULT_CERT_DOMAIN placeholder in php ssl config"
sed -e "s#__VAULT_CERT_DOMAIN__#$VAULT_CERT_DOMAIN#g" /data/php/conf/default-ssl.conf

_info "Start mysql container"
cd /data/docker-demo-stack && \
  docker-compose up -d mysql

_info "Start mongodb container"
cd /data/docker-demo-stack && \
  docker-compose up -d mongodb

_info "Start openldap container"
cd /data/docker-demo-stack && \
  docker-compose up -d openldap

_info "Sleep 20"
sleep 20

_info "Start ldap-ui container"
cd /data/docker-demo-stack && \
  docker-compose up -d ldap-ui

_info "Start mongo-gui container"
cd /data/docker-demo-stack && \
  docker-compose up -d mongo-gui

_info "Configure mysql"
mysql -u$MYSQL_ROOT_USERNAME -p$MYSQL_ROOT_PASSWORD -h$MYSQL_HOST -t<<EOF
DROP user if exists '$MYSQL_VAULT_USERNAME';
CREATE USER '$MYSQL_VAULT_USERNAME'@'%' IDENTIFIED BY '$MYSQL_VAULT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_VAULT_USERNAME'@'%' WITH GRANT OPTION;

DROP user if exists '$MYSQL_STATIC_USERNAME';
CREATE USER '$MYSQL_STATIC_USERNAME'@'%' IDENTIFIED BY '$MYSQL_STATIC_PASSWORD';
GRANT ALL PRIVILEGES ON demodb.pii to '$MYSQL_STATIC_USERNAME'@'%';

DROP DATABASE IF EXISTS $MYSQL_DB_NAME;
CREATE DATABASE $MYSQL_DB_NAME;

CREATE TABLE IF NOT EXISTS $MYSQL_DB_NAME.$MYSQL_DB_TABLE (
  id INT NOT NULL AUTO_INCREMENT,
  name varchar(256),
  phone varchar(256),
  email varchar(256),
  dob varchar(256),
  ssn varchar(256),
  ccn varchar(256),
  expire varchar(256),
  brn varchar(256),
  ban varchar(256),
  PRIMARY KEY ( id )
);

GRANT ALL PRIVILEGES ON $MYSQL_DB_NAME.* TO '$MYSQL_STATIC_USERNAME'@'%' IDENTIFIED BY '$MYSQL_STATIC_PASSWORD';
EOF

_info "Enable database secrets engine for myql"
vault secrets disable $MYSQL_PATH
vault secrets enable -path $MYSQL_PATH database

_info "Configure vault mysql database connection"
vault write $MYSQL_PATH/config/$MYSQL_DB_NAME \
  plugin_name=mysql-database-plugin \
  connection_url="{{username}}:{{password}}@tcp($MYSQL_HOST:$MYSQL_PORT)/" \
  allowed_roles="$MYSQL_ROLE" \
  username="$MYSQL_VAULT_USERNAME" \
  password="$MYSQL_VAULT_PASSWORD"

_info "Configure vault mysql role"
vault write $MYSQL_PATH/roles/$MYSQL_ROLE \
  db_name=$MYSQL_DB_NAME \
  creation_statements="GRANT ALL PRIVILEGES ON $MYSQL_DB_NAME.* TO '{{name}}'@'%' IDENTIFIED BY '{{password}}';" \
  default_ttl="2m" \
  max_ttl="10m"

_info "Enable database secrets engine for mongo"
vault secrets disable $MONGODB_PATH
vault secrets enable -path $MONGODB_PATH database

_info "Configure vault mongo database connection"
vault write $MONGODB_PATH/config/$MONGODB_DB_NAME \
  plugin_name=mongodb-database-plugin \
  connection_url=mongodb://{{username}}:{{password}}@$MONGODB_URL \
  tls_ca=@$CERT_DIR/wildcard/ca.pem \
  allowed_roles=$MONGODB_ROLE \
  username=$MONGODB_ROOT_USERNAME \
  password=$MONGODB_ROOT_PASSWORD

_info "Configure vault mongo role"
vault write $MONGODB_PATH/roles/$MONGODB_ROLE \
  db_name=$MONGODB_DB_NAME \
  creation_statements="{ \"db\": \"$MONGODB_DB_NAME\", \"roles\": [{ \"role\": \"readWrite\", \"db\": \"$MONGODB_DB_NAME\" }] }" \
  revocation_statements='{"db":"demo"}' \
  default_ttl="1h" \
  max_ttl="24h"

# Policies
_info "Configure vault policies"

_info "Configure vault admin policy"
vault policy write admin -<<EOF
# full admin rights
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

EOF

_info "Configure vault web application policy"
vault policy write $WEB_POLICY -<<EOF
# pki cert consumer - intermediate CA
path "$INTERMEDIATE_CA_NAME/*" {
  capabilities = ["list"]
}
path "$INTERMEDIATE_CA_NAME/issue*" {
  capabilities = ["create","update"]
}
path "$INTERMEDIATE_CA_NAME/config*" {
  capabilities = ["list","create","update"]
}
path "$INTERMEDIATE_CA_NAME/config/crl*" {
  capabilities = ["read","list","create","update"]
}
path "$INTERMEDIATE_CA_NAME/config/urls*" {
  capabilities = ["read","list","create","update"]
}

# pki cert consumer - imported CA
path "$IMPORTED_CA_NAME/*" {
  capabilities = ["list"]
}
path "$IMPORTED_CA_NAME/issue*" {
  capabilities = ["create","update"]
}
path "$IMPORTED_CA_NAME/config*" {
  capabilities = ["list","create","update"]
}
path "$IMPORTED_CA_NAME/config/crl*" {
  capabilities = ["read","list","create","update"]
}
path "$IMPORTED_CA_NAME/config/urls*" {
  capabilities = ["read","list","create","update"]
}

# kv - static db creds
path "$KV_PATH/data/$KV_MYSQL_PATH" {
  capabilities = ["read"]
}

# dynamic db creds
path "$MYSQL_PATH/creds/$MYSQL_ROLE" {
  capabilities = ["read"]
}

# token management
path "auth/token/renew" {
  capabilities = ["update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

_info "Configure vault decrypt policy"
vault policy write $TRANSIT_DECRYPT_POLICY -<<EOF
# grant permissions to decrypt data
path "$TRANSIT_PATH/decrypt/$TRANSIT_KEY" {
  capabilities = [ "update" ]
}

EOF

_info "Configure vault encrypt / rotate policy"
vault policy write $TRANSIT_ENCRYPT_POLICY - <<EOF
# grant permissions to encrypt data
path "$TRANSIT_PATH/encrypt/$TRANSIT_KEY" {
  capabilities = [ "update" ]
}

# grant permissions to read encryption key
path "$TRANSIT_PATH/keys/$TRANSIT_KEY" {
  capabilities = [ "read" ]
}

# grant permissions to rotate encryption key
path "$TRANSIT_PATH/keys/$TRANSIT_KEY/rotate" {
  capabilities = [ "update" ]
}

EOF

_info "Configure vault engineers policy"
vault policy write engineers - <<EOF
# grant permissions to engineering kv secrets
path "$KV_PATH/metadata/engineering" {
  capabilities = ["list"]
}

path "$KV_PATH/data/engineering/*" {
  capabilities = ["read", "list", "update", "create"]
}
EOF

# Namespaces
_info "Create namespaces"
for i in ${NAMESPACES//,/ }
do
  _info "Create namespace $i"
  vault namespace create $i
done

# Auth
_info "Enable vault userpass auth"
vault auth disable $USERPASS_AUTH_PATH
vault auth enable -path=$USERPASS_AUTH_PATH userpass

_info "Enable vault ldap auth"
vault auth disable $LDAP_AUTH_PATH
vault auth enable -path=$LDAP_AUTH_PATH ldap

_info "Configure vault ldap auth"
vault write auth/$LDAP_AUTH_PATH/config \
  binddn="cn=admin,dc=example,dc=com" \
  bindpass='password' \
  userattr='uid' \
  url="ldaps://openldap.$DOMAIN" \
  userdn="ou=users,dc=example,dc=com" \
  groupdn="ou=users,dc=example,dc=com" \
  groupattr="groupOfNames" \
  certificate=@$CERT_DIR/wildcard/ca.pem \
  insecure_tls=false \
  starttls=true

_info "Configure vault ldap engineers group"
vault write auth/$LDAP_AUTH_PATH/groups/engineers policies=engineers

# Generate Vault clients
_info "Generate vault clients"

_info "Get userpass mount accessor"
export USERPASS_MOUNT_ACCESSOR=$(vault auth list -detailed | grep $USERPASS_AUTH_PATH | awk '{print $3}')
_info "USERPASS_MOUNT_ACCESSOR is $USERPASS_MOUNT_ACCESSOR"

_info "Get ldap mount accessor"
export LDAP_MOUNT_ACCESSOR=$(vault auth list -detailed  | grep $LDAP_AUTH_PATH | awk '{print $3}')
_info "LDAP_MOUNT_ACCESSOR is $LDAP_MOUNT_ACCESSOR"

for i in ${LDAP_USERS//,/ }
do
  _info "Create user $i in ldap auth method"
  vault write auth/$LDAP_AUTH_PATH/users/$i \
    policies=$i

  _info "Generate vault entity for $i"
  VAULT_ENTITY_ID=$(vault write -format=json identity/entity name="$i" policies="$i" | jq -r ".data.id")

  _info "Generate userpass user $i"
  vault write auth/$USERPASS_AUTH_PATH/users/$i password=$i policies=$i

  _info "Map ldap alias $i to entity $i"
  vault write identity/entity-alias name="$i" \
     canonical_id=$VAULT_ENTITY_ID \
     mount_accessor=$LDAP_MOUNT_ACCESSOR \

  _info "Map userpass alias $i to entity $i"
  vault write identity/entity-alias name="$i" \
    canonical_id=$VAULT_ENTITY_ID \
    mount_accessor=$USERPASS_MOUNT_ACCESSOR

  _info "Write test kv secret for user $i"
  vault kv put $KV_PATH/$i/test x=$(uuidgen) y=$(uuidgen)

  _info "Create policy for $i"
  vault policy write $i - <<EOF
# grant permissions to user kv secrets
path "$KV_PATH/metadata/$i" {
  capabilities = ["list"]
}

path "$KV_PATH/data/$i/*" {
  capabilities = ["read", "list", "update", "create"]
}
EOF
  #vault write auth/$LDAP_AUTH_PATH/users/$i policies=$i

  _info "Logging into vault via ldap auth as $i"
  VAULT_TOKEN=$(vault login -format=json -method=ldap username=$i password=$i | jq -r .auth.client_token) vault kv list -format=json kv/$i > /dev/null

  _info "Logging into vault via userpass auth as $i"
  VAULT_TOKEN=$(vault login -format=json -method=userpass username=$i password=$i | jq -r .auth.client_token) vault kv list -format=json kv/$i > /dev/null
done

_info "Cleaning up ~/.vault-token"
rm -f ~/.vault-token

_info "Configuring vault admin user $LDAP_USER_VAULT_ADMIN"
vault write auth/$LDAP_AUTH_PATH/users/$LDAP_USER_VAULT_ADMIN \
  policies=$LDAP_USER_VAULT_ADMIN,admin

vault write auth/$USERPASS_AUTH_PATH/users/$LDAP_USER_VAULT_ADMIN \
  password=$LDAP_USER_VAULT_ADMIN \
  policies=$LDAP_USER_VAULT_ADMIN,admin

# LDAP auth in each namespace
for n in ${NAMESPACES//,/ }
do

  # KV
  _info "Enable KV secrets engine in namespace $n"
  VAULT_NAMESPACE=$n vault secrets disable $KV_PATH
  VAULT_NAMESPACE=$n vault secrets enable -path $KV_PATH kv-v2
  
  _info "Write kv secret to $KV_PATH/engineering/app1"
  VAULT_NAMESPACE=$n vault kv put $KV_PATH/engineering/$n-app1 user=$(uuidgen) pass=$(uuidgen)

  _info "Enable vault ldap auth in namespace $n"
  VAULT_NAMESPACE=$n vault auth disable $LDAP_AUTH_PATH
  VAULT_NAMESPACE=$n vault auth enable -path=$LDAP_AUTH_PATH ldap

  _info "Enable vault userpass auth in namespace $n"
  VAULT_NAMESPACE=$n vault auth disable $USERPASS_AUTH_PATH
  VAULT_NAMESPACE=$n vault auth enable -path=$USERPASS_AUTH_PATH userpass
  
  _info "Configure vault ldap auth in namespace $n"
  VAULT_NAMESPACE=$n vault write auth/$LDAP_AUTH_PATH/config \
    binddn="cn=admin,dc=example,dc=com" \
    bindpass='password' \
    userattr='uid' \
    url="ldaps://openldap.$DOMAIN" \
    userdn="ou=users,dc=example,dc=com" \
    groupdn="ou=users,dc=example,dc=com" \
    groupattr="groupOfNames" \
    certificate=@$CERT_DIR/wildcard/ca.pem \
    insecure_tls=false \
    starttls=true

  _info "Configure vault ldap engineers group in namespace $n"
  VAULT_NAMESPACE=$n vault write auth/$LDAP_AUTH_PATH/groups/engineers policies=engineers
    
    # Generate Vault clients
  _info "Generate vault clients in namespace $n"
    
    _info "Get userpass mount accessor"
    export USERPASS_MOUNT_ACCESSOR=$(VAULT_NAMESPACE=$n vault auth list -detailed | grep $USERPASS_AUTH_PATH | awk '{print $3}')
    _info "USERPASS_MOUNT_ACCESSOR is $USERPASS_MOUNT_ACCESSOR"
    
    _info "Get ldap mount accessor"
    export LDAP_MOUNT_ACCESSOR=$(VAULT_NAMESPACE=$n vault auth list -detailed  | grep $LDAP_AUTH_PATH | awk '{print $3}')
    _info "LDAP_MOUNT_ACCESSOR is $LDAP_MOUNT_ACCESSOR"
    
    for i in ${LDAP_USERS//,/ }
    do
      _info "Create user $i in ldap auth method in namespace $n"
      VAULT_NAMESPACE=$n vault write auth/$LDAP_AUTH_PATH/users/$i \
        policies=$i

      _info "Generate vault entity for $i in namespace $n"
      VAULT_ENTITY_ID=$(VAULT_NAMESPACE=$n vault write -format=json identity/entity name="$i" policies="$n-$i" | jq -r ".data.id")
    
      _info "Generate userpass user $i in namespace $n"
      VAULT_NAMESPACE=$n vault write auth/$USERPASS_AUTH_PATH/users/$i password=$i policies=$n-$i
    
      _info "Map ldap alias $i to entity $i in namespace $n"
      VAULT_NAMESPACE=$n vault write identity/entity-alias name="$i" \
         canonical_id=$VAULT_ENTITY_ID \
         mount_accessor=$LDAP_MOUNT_ACCESSOR \
    
      _info "Map userpass alias $i to entity $i in namespace $n"
      VAULT_NAMESPACE=$n vault write identity/entity-alias name="$i" \
        canonical_id=$VAULT_ENTITY_ID \
        mount_accessor=$USERPASS_MOUNT_ACCESSOR
    
      _info "Write test kv secret for user $i in namespace $n"
      VAULT_NAMESPACE=$n vault kv put $KV_PATH/$n-$i/test x=$(uuidgen) y=$(uuidgen)
    
      _info "Create policy for $n-$i in namespace $n"
      VAULT_NAMESPACE=$n vault policy write $n-$i - <<EOF
# grant permissions to user kv secrets
path "$KV_PATH/metadata/$n-$i" {
  capabilities = ["list"]
}

path "$KV_PATH/data/$n-$i/*" {
  capabilities = ["read", "list", "update", "create"]
}
EOF

      #VAULT_NAMESPACE=$n vault write auth/$LDAP_AUTH_PATH/users/$i policies=$i
    
      _info "Logging into vault via ldap auth as $i in namespace $n"
      VAULT_TOKEN=$(VAULT_NAMESPACE=$n vault login -format=json -method=ldap username=$i password=$i | jq -r .auth.client_token) VAULT_NAMESPACE=$n vault kv list -format=json kv/$n-$i > /dev/null
    
      _info "Logging into vault via userpass auth as $i in namespace $n"
      VAULT_TOKEN=$(VAULT_NAMESPACE=$n vault login -format=json -method=userpass username=$i password=$i | jq -r .auth.client_token) VAULT_NAMESPACE=$n vault kv list -format=json kv/$n-$i > /dev/null
    done
    
    _info "Cleaning up ~/.vault-token"
    rm -f ~/.vault-token
done

# generate some non-entity clients
for i in $(seq 1 $(shuf -i 10-25 -n 1))
do
  vault kv put $KV_PATH/rogue$i/rogue$i $(uuidgen)=$(uuidgen)
  vault policy write rogue$i -<<EOF
path "$KV_PATH/data/rogue$i/*" {
  capabilities = ["read", "list", "update", "create"]
}

path "$KV_PATH/delete/rogue$i/*" {
  capabilities = ["update"]
}

path "$KV_PATH/undelete/rogue$i/*" {
  capabilities = ["update"]
}

path "$KV_PATH/destroy/rogue$i/*" {
  capabilities = ["update"]
}

path "$KV_PATH/metadata/rogue$i/*" {
  capabilities = ["list"]
}

path "$KV_PATH/metadata/rogue$i/*" {
  capabilities = ["read"]
}

path "$KV_PATH/metadata/rogue$i/*" {
  capabilities = ["delete"]
}
EOF

  VAULT_TOKEN=$(vault token create -policy=rogue$i -format=json | jq -r .auth.client_token) vault kv get kv/rogue$i/rogue$i
done



# Vault Agent
_info "Configuring Vault Agent"
mkdir -p $VAULT_AGENT_PATH

_info "Writing AppRole role_id for Vault Agent"
export VAULT_ROLE_ID=$(vault read -format=json auth/$APPROLE_PATH/role/$WEB_ROLE/role-id | jq -r '.data.role_id')
echo $VAULT_ROLE_ID > $VAULT_AGENT_PATH/role_id

_info "Writing AppRole secret_id for Vault Agent"
export VAULT_SECRET_ID=$(vault write -f -format=json auth/$APPROLE_PATH/role/$WEB_ROLE/secret-id | jq -r '.data.secret_id')
echo $VAULT_SECRET_ID > $VAULT_AGENT_PATH/secret_id

_info "Writing vault-agent systemd unit file"
cat <<EOF > /etc/systemd/system/vault-agent.service
[Unit]
Description=Vault Agent
#Requires=vault.service
#After=vault.service

[Service]
Restart=on-failure
EnvironmentFile=$VAULT_AGENT_PATH/vault-agent.env
PermissionsStartOnly=true
ExecStart=/usr/bin/vault agent -config $VAULT_AGENT_PATH/vault-agent.hcl
KillSignal=SIGTERM
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

_info "Writing vault-agent environment file"
cat <<EOF > $VAULT_AGENT_PATH/vault-agent.env
VAULT_ADDR=https://vault.$DOMAIN:8200
VAULT_SKIP_VERIFY=true
TRANSIT_ENCRYPT_TOKEN=$TRANSIT_ENCRYPT_TOKEN
TRANSIT_DECRYPT_TOKEN=$TRANSIT_DECRYPT_TOKEN
MYSQL_STATIC_USERNAME=$MYSQL_STATIC_USERNAME
MYSQL_STATIC_PASSWORD=$MYSQL_STATIC_PASSWORD
MYSQL_DB_NAME=$MYSQL_DB_NAME
MYSQL_DB_TABLE=$MYSQL_DB_TABLE
MYSQL_HOST=$MYSQL_HOST
WEB_SERVER_URL=https://web.$VAULT_CERT_DOMAIN/
EOF

cat <<EOF > $VAULT_AGENT_PATH/vault-agent.hcl
exit_after_auth = false

pid_file = "$VAULT_AGENT_PATH/pidfile"

vault {
  address = "$VAULT_ADDR"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      type                = "approle"
      role                = "demo-role"
      role_id_file_path   = "$VAULT_AGENT_PATH/role_id"
      secret_id_file_path = "$VAULT_AGENT_PATH/secret_id"
      bind_secret_id      = false

      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "$VAULT_AGENT_PATH/vault-token"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8100"
  tls_disable = true
}

template_config {
  static_secret_render_interval = "15s"
}

template {
  source      = "/data/web/db-secure.php.tpl"
  destination = "/data/web/db-secure.php"
  perms       = 0644
  #command     =
}

#template {
#  source      = "/data/web/db-static.php.tpl"
#  destination = "/data/web/db-static.php"
#  perms       = 0644
#}

template {
  source       = "$VAULT_CERT_DIR/privkey.tpl"
  destination  = "$VAULT_CERT_DIR/privkey.pem"
  perms        = 0644
  command      = "$VAULT_AGENT_PATH/restart-web.sh"
}

template {
  source       = "$VAULT_CERT_DIR/fullchain.tpl"
  destination  = "$VAULT_CERT_DIR/fullchain.pem"
  perms        = 0644
  command      = "$VAULT_AGENT_PATH/restart-web.sh"
}

EOF

_info "Writing vault agent restart-web.sh script"
cat <<EOF > $VAULT_AGENT_PATH/restart-web.sh
#!/bin/bash

export TRANSIT_ENCRYPT_TOKEN=$TRANSIT_ENCRYPT_TOKEN
export TRANSIT_DECRYPT_TOKEN=$TRANSIT_DECRYPT_TOKEN
export MYSQL_STATIC_USERNAME=$MYSQL_STATIC_USERNAME
export MYSQL_STATIC_PASSWORD=$MYSQL_STATIC_PASSWORD
export MYSQL_DB_NAME=$MYSQL_DB_NAME
export MYSQL_DB_TABLE=$MYSQL_DB_TABLE
export MYSQL_HOST=$MYSQL_HOST
export VAULT_ADDR=$VAULT_ADDR
export WEB_SERVER_URL=https://web.$VAULT_CERT_DOMAIN/

cd /data/docker-demo-stack && \
  docker-compose stop web && \
  docker-compose rm -f web && \
  docker-compose up -d web 

#docker exec -it web apachectl -k graceful

EOF

_info "Setting permissions on restart-web.sh script"
chmod 0755 $VAULT_AGENT_PATH/restart-web.sh

_info "Writing privkey.tpl template file"
cat <<EOF > $VAULT_CERT_DIR/privkey.tpl
{{ with secret "$IMPORTED_CA_NAME/issue/$VAULT_CERT_DOMAIN" "common_name=web.$VAULT_CERT_DOMAIN" }}
{{ .Data.private_key }}
{{ end }}
EOF

_info "Writing fullchain.tpl template file"
cat <<EOF > $VAULT_CERT_DIR/fullchain.tpl
{{ with secret "$IMPORTED_CA_NAME/issue/$VAULT_CERT_DOMAIN" "common_name=web.$VAULT_CERT_DOMAIN" }}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}
{{ end }}
EOF

_info "Copy web app to /data/web"
mkdir -p /data/web && \
  cd /data/$REPODIR/web && \
  cp -r * /data/web && \
  cd /data

_info "Start vault-agent"
systemctl daemon-reload && \
  systemctl enable vault-agent && \
  systemctl start vault-agent

# Mongo synthetic data
_info "Generate synthetic data in mongo"
mkdir -p /data/mongodb/nodejsapp && \
  cd /data/$REPODIR/mongodb/nodejsapp && \
  cp app.js package.json /data/mongodb/nodejsapp && \
  cd /data/mongodb/nodejsapp && \
  npm install express && \
  npm install mongodb && \
  npm install @faker-js/faker && \
  node app.js

_info "Finished bootstrap.sh"

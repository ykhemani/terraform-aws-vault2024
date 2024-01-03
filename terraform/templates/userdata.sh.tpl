#! /bin/bash

# config
DOMAIN="${domain}"
VAULT_LICENSE="${vault_license}"
LDAP_USERS="${ldap_users}"
LDAP_USER_VAULT_ADMIN="${ldap_user_vault_admin}"
CERT_DIR="${cert_dir}"
SSH_IMPORT_ID="${ssh_import_id}"
GITREPO=${gitrepo}
REPODIR=${repodir}

if ["$SSH_IMPORT_ID" != "" ]
then
  ssh-import-id $SSH_IMPORT_ID
fi

REQUIRED_PACKAGES="git wget jq htop vault-enterprise boundary-enterprise consul-enterprise nomad-enterprise terraform packer consul-template envconsul mysql-client ldap-utils"
DOCKER_PACKAGES="docker-ce docker-ce-cli containerd.io docker-buildx-plugin"

# have_program is a helper function to determine if a package is installed
function have_program {
  [ -x "$(which $1)" ]
}

# install_tools installs any necessary tools used in this script
function install_packages {
  echo "[INFO] Installing necessary tools..."
  
  # Determine package manager to use
  if have_program apt-get; then
    package_manager="apt-get"

    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main"

    sudo $package_manager update -y

    for pkg in docker.io docker-doc podman-docker containerd runc; do sudo apt-get remove $pkg; done
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

  elif have_program yum; then
    package_manager="yum"

    sudo yum install -y yum-utils
    sudo yum-config-manager \
      --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

    sudo yum remove \
      docker \
      docker-client \
      docker-client-latest \
      docker-common \
      docker-latest \
      docker-latest-logrotate \
      docker-logrotate \
      docker-engine \
      podman \
      runc

    sudo yum-config-manager \
      --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
  fi
  
  # Install required packages
  sudo $package_manager install -y $REQUIRED_PACKAGES $DOCKER_PACKAGES

  sudo curl -sL "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
  echo "[INFO] Done installing packages."
}

%{ if install_packages == true ~}
install_packages
%{ endif ~}

# add user ubuntu to docker group
usermod -aG docker ubuntu

# auto-complete install 
# vault -autocomplete-install
cat <<EOF >> /root/.bashrc
complete -C /usr/bin/vault vault
complete -C /usr/bin/consul consul
complete -C /usr/bin/terraform terraform
complete -C /usr/bin/nomad nomad
complete -C /usr/bin/packer packer
EOF

# vault docker
mkdir -p \
  /data/vault/data \
  /data/vault/conf \
  /data/vault/audit \
  /data/vault/plugins \
  /data/vault/license \
  $CERT_DIR/wildcard

chown -R 100:1000 /data/vault

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

##########
# certs
sudo mkdir -p $CERT_DIR && cd $CERT_DIR

# Wildcard Private Key
cat <<EOF > $CERT_DIR/wildcard/privkey.pem
${wildcard_private_key}
EOF

# Wildcard Cert
cat <<EOF > $CERT_DIR/wildcard/cert.pem
${wildcard_cert}
EOF

# Wildcard CA Cert
cat <<EOF > $CERT_DIR/wildcard/ca.pem
${ca_cert}
EOF

cp $CERT_DIR/wildcard/ca.pem /usr/local/share/ca-certificates/demo-ca.pem

# Wildcard Fullchain
cat $CERT_DIR/wildcard/cert.pem > $CERT_DIR/wildcard/fullchain.pem
cat $CERT_DIR/wildcard/ca.pem >> $CERT_DIR/wildcard/fullchain.pem

sudo update-ca-certificates

# install vault license
echo $VAULT_LICENSE > /data/vault/license/vault.hclic

# Enable and start Docker
sudo systemctl enable docker && \
sudo systemctl start docker

##########
# Create Vault environment
mkdir -p ~/venv && \
  cd ~/venv
cat <<EOF > ~/venv/venv
export VAULT_ADDR=https://vault.$DOMAIN:8200
export VAULT_SKIP_VERIFY=true
export VAULT_TOKEN=\$(cat ~/venv/vault-init.json | jq -r .root_token)
export VAULT_UNSEAL=\$(cat ~/venv/vault-init.json | jq -r .unseal_keys_b64[])

export CERT_DIR=$CERT_DIR

# ldap auth
export LDAP_AUTH_PATH=ldap

# approle auth for web app
export APPROLE_PATH=approle
export WEB_ROLE=web-role
export WEB_POLICY=web-policy

# pki
export ROOT_CA_NAME=vault-ca-root
export INTERMEDIATE_CA_NAME=vault-ca-intermediate
export VAULT_CERT_DOMAIN=demo.$DOMAIN
export VAULT_CERT_DIR="$CERT_DIR/demo.$DOMAIN"

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

export MYSQL_PATH=database
export MYSQL_DB_PATH=mysql-demo
export MYSQL_ROLE=mysql-web-role

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
. ~/venv/venv

cat <<EOF >> ~/.bashrc

if [ -f ~/venv/venv ]
then
  . ~/venv/venv
fi

EOF

echo "127.0.0.1 vault.$DOMAIN mysql.$DOMAIN openldap.$DOMAIN ldap.$DOMAIN web.$VAULT_CERT_DOMAIN" >> /etc/hosts

# placeholder values
export TRANSIT_ENCRYPT_TOKEN="TRANSIT_ENCRYPT_TOKEN"
export TRANSIT_DECRYPT_TOKEN="TRANSIT_DECRYPT_TOKEN"

# docker-compose.yaml
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

secrets:
  wildcard_privkey:
    file: $CERT_DIR/wildcard/privkey.pem
  wildcard_cert:
    file: $CERT_DIR/wildcard/fullchain.pem
  wildcard_ca_cert:
    file: $CERT_DIR/wildcard/ca.pem
  wildcard_fullchain:
    file: $CERT_DIR/wildcard/fullchain.pem
  vault_license:
    file: /data/vault/license/vault.hclic
  mysql_root_password:
    file: /data/mysql/secrets/mysql_root_password
  web_pki_privkey:
    file: $CERT_DIR/$VAULT_CERT_DOMAIN/privkey.pem
  web_pki_cert:
    file: $CERT_DIR/$VAULT_CERT_DOMAIN/fullchain.pem
EOF

# Start Vault
 cd /data/docker-demo-stack && \
   docker-compose up -d vault

##########
# Initialize Vault
vault operator init \
  -format=json \
  -key-shares=1 \
  -key-threshold=1 \
  | tee ~/venv/vault-init.json
. ~/venv/venv

##########
# Unseal Vault
vault operator unseal $VAULT_UNSEAL

##########
# Configure Audit Logs
vault audit enable file file_path=/vault/audit/audit.log && \
  vault audit enable -path=raw file \
    file_path=/vault/audit/raw.log log_raw=true
#vault audit list -detailed

##########
# Configure AppRole Auth
vault auth enable -path=$APPROLE_PATH approle

vault write auth/$APPROLE_PATH/role/$WEB_ROLE \
  secret_id_ttl=0 \
  token_num_uses=0 \
  token_ttl=720h \
  token_max_ttl=720h \
  secret_id_num_uses=0 \
  token_policies=$WEB_POLICY

mkdir -p $VAULT_AGENT_PATH

export VAULT_ROLE_ID=$(vault read -format=json auth/$APPROLE_PATH/role/$WEB_ROLE/role-id | jq -r '.data.role_id')
echo $VAULT_ROLE_ID > $VAULT_AGENT_PATH/role_id

export VAULT_SECRET_ID=$(vault write -f -format=json auth/$APPROLE_PATH/role/$WEB_ROLE/secret-id | jq -r '.data.secret_id')
echo $VAULT_SECRET_ID > $VAULT_AGENT_PATH/secret_id

#vault agent -config $VAULT_AGENT_PATH/vault-agent.hcl

##########
# ssh secrets engine
vault secrets enable -path $SSH_PATH ssh

##########
# pki
mkdir -p $VAULT_CERT_DIR

# pki secret engine for root ca
vault secrets enable -path $ROOT_CA_NAME pki

# max ttl for root ca
vault secrets tune -max-lease-ttl=87600h $ROOT_CA_NAME

# generate root ca cert
vault write -format=json $ROOT_CA_NAME/root/generate/internal \
  common_name="ca.$VAULT_CERT_DOMAIN" ttl=87600h \
  issuer_name="root-2023" | tee \
  >(jq -r .data.certificate > $VAULT_CERT_DIR/vault-ca-root.pem)

# configure ca and crl url's for root ca
vault write $ROOT_CA_NAME/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/$ROOT_CA_NAME/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/$ROOT_CA_NAME/crl"

# enable pki secret engine for intermediate ca
vault secrets enable -path $INTERMEDIATE_CA_NAME pki

# max ttl for intermediate ca
vault secrets tune -max-lease-ttl=43800h $INTERMEDIATE_CA_NAME

# configure ca and crl url's for intermediate ca
vault write $INTERMEDIATE_CA_NAME/config/urls \
  issuing_certificates="$VAULT_ADDR/v1/$INTERMEDIATE_CA_NAME/ca" \
  crl_distribution_points="$VAULT_ADDR/v1/$INTERMEDIATE_CA_NAME/crl"

# generate csr for intermediate ca that will be signed by root ca
vault write -format=json \
  $INTERMEDIATE_CA_NAME/intermediate/generate/internal \
  common_name="$VAULT_CERT_DOMAIN Intermediate Authority" \
  issuer_name="demo-seva-cafe-intermediate-2023" | tee \
  >(jq -r .data.csr > $VAULT_CERT_DIR/vault-ca-intermediate.csr)

# sign the intermediate ca csr using root ca
vault write -format=json \
  $ROOT_CA_NAME/root/sign-intermediate \
  issuer_ref="root-2023" \
  csr=@$VAULT_CERT_DIR/vault-ca-intermediate.csr \
  common_name="$VAULT_CERT_DOMAIN Intermediate Authority" ttl=43800h | tee \
  >(jq -r .data.certificate > $VAULT_CERT_DIR/vault-ca-intermediate.pem)

# set intermediate ca as signed
vault write $INTERMEDIATE_CA_NAME/intermediate/set-signed \
  certificate=@$VAULT_CERT_DIR/vault-ca-intermediate.pem

# create role for issuing certs
vault write $INTERMEDIATE_CA_NAME/roles/$VAULT_CERT_DOMAIN \
  allowed_domains="$VAULT_CERT_DOMAIN" \
  allow_subdomains="true" \
  ttl="1h" \
  max_ttl="24h" \
  generate_lease=true

##########
# transit secrets engine

mkdir -p $TOKEN_PATH

vault secrets disable $TRANSIT_PATH
vault secrets enable -path $TRANSIT_PATH transit

vault write -f $TRANSIT_PATH/keys/$TRANSIT_KEY

# decrypt token
vault token create -format=json -ttl=720h -policy=$TRANSIT_DECRYPT_POLICY -orphan | tee $TOKEN_PATH/$TRANSIT_DECRYPT_POLICY-token.json

# encrypt token
vault token create -format=json -ttl=720h -policy=$TRANSIT_ENCRYPT_POLICY -orphan | tee $TOKEN_PATH/$TRANSIT_ENCRYPT_POLICY-token.json

export TRANSIT_ENCRYPT_TOKEN=$(cat $TOKEN_PATH/$TRANSIT_ENCRYPT_POLICY-token.json | jq -r .auth.client_token)
export TRANSIT_DECRYPT_TOKEN=$(cat $TOKEN_PATH/$TRANSIT_DECRYPT_POLICY-token.json | jq -r .auth.client_token)

echo "export TRANSIT_ENCRYPT_TOKEN=$TRANSIT_ENCRYPT_TOKEN" >> ~/venv/venv
echo "export TRANSIT_DECRYPT_TOKEN=$TRANSIT_DECRYPT_TOKEN" >> ~/venv/venv

##########
# transform secrets engine (fpe)

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

##########
# transform secrets engine (tokenization) (work-in-progress)
vault secrets disable $TRANSFORM_TOKENIZATION_PATH
vault secrets enable -path $TRANSFORM_TOKENIZATION_PATH transform

vault write $TRANSFORM_TOKENIZATION_PATH/role/$TRANSFORM_TOKENIZATION_ROLE transformations=credit-card

vault write $TRANSFORM_TOKENIZATION_PATH/transformations/tokenization/credit-card \
  allowed_roles=$TRANSFORM_TOKENIZATION_ROLE

##########
# clone git repo
cd /data && \
  git clone $GITREPO $REPODIR

# web docker image
cd /data/$REPODIR/php && \
  docker build -t php:8.1.1-apache-mysqli .

mkdir -p /data/php/conf && \
  cd /data/$REPODIR/php/conf && \
  cp * /data/php/conf/ && \
  cd /data

# mysql docker image
docker pull mysql:5.7

##########
# database and web

mkdir -p \
  /data/mysql/etc \
  /data/mysql/var/lib/mysql \
  /data/mysql/dump \
  /data/mysql/secrets \
  /data/openldap \
  /data/php/conf \
  $CERT_DIR/web.$VAULT_CERT_DOMAIN

chown 1001 /data/openldap

cat <<EOF >> /etc/ldap/ldap.conf
TLS_CACERT      $CERT_DIR/wildcard/ca.pem
EOF

touch \
  /data/mysql/etc/my.cnf \
  /data/mysql/secrets/mysql_root_password

echo $MYSQL_ROOT_PASSWORD > /data/mysql/secrets/mysql_root_password

# web

sed -e "s#__VAULT_CERT_DOMAIN__#$VAULT_CERT_DOMAIN#g" /data/php/conf/default-ssl.conf

##########
# mysql

cd /data/docker-demo-stack && docker-compose up -d mysql && docker-compose up -d openldap

# sleep to let mysql container restart
sleep 20;

# configure mysql
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

# database secrets engine
vault secrets disable $MYSQL_PATH
vault secrets enable -path $MYSQL_PATH database

vault write $MYSQL_PATH/config/$MYSQL_DB_NAME \
  plugin_name=mysql-database-plugin \
  connection_url="{{username}}:{{password}}@tcp($MYSQL_HOST:$MYSQL_PORT)/" \
  allowed_roles="$MYSQL_ROLE" \
  username="$MYSQL_VAULT_USERNAME" \
  password="$MYSQL_VAULT_PASSWORD"

vault write $MYSQL_PATH/roles/$MYSQL_ROLE \
  db_name=$MYSQL_DB_NAME \
  creation_statements="GRANT ALL PRIVILEGES ON $MYSQL_DB_NAME.* TO '{{name}}'@'%' IDENTIFIED BY '{{password}}';" \
  default_ttl="2m" \
  max_ttl="10m"

##########
# policies

# admin policy
vault policy write admin -<<EOF
# full admin rights
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

EOF

# web policy
vault policy write $WEB_POLICY -<<EOF
# pki cert consumer
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

# decrypt
vault policy write $TRANSIT_DECRYPT_POLICY -<<EOF
# grant permissions to decrypt data
path "$TRANSIT_PATH/decrypt/$TRANSIT_KEY" {
  capabilities = [ "update" ]
}

EOF

# encrypt / rotate
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

# decrypt
vault policy write $TRANSIT_DECRYPT_POLICY - <<EOF
# grant permissions to decrypt data
path "$TRANSIT_PATH/decrypt/$TRANSIT_KEY" {
  capabilities = [ "update" ]
}
EOF

# engineers
vault policy write engineers - <<EOF
# grant permissions to engineering kv secrets
path "$KV_PATH/metadata/engineering" {
  capabilities = ["list"]
}

path "$KV_PATH/data/engineering/*" {
  capabilities = ["read", "list", "update", "create"]
}
EOF

# kv
vault secrets enable -path $KV_PATH kv-v2
vault kv put $KV_PATH/engineering/app1 user=$(uuidgen) pass=$(uuidgen)

# ldap auth
vault auth disable $LDAP_AUTH_PATH
vault auth enable -path=$LDAP_AUTH_PATH ldap

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

vault write auth/$LDAP_AUTH_PATH/groups/engineers policies=engineers

# generate vault clients

export LDAP_MOUNT_ACCESSOR=$(vault auth list -detailed  | grep $LDAP_AUTH_PATH | awk '{print $3}')
for i in $${LDAP_USERS//,/ }
do

  VAULT_ENTITY_ID=$(vault write -format=json identity/entity name="$i" policies="$i" | jq -r ".data.id")

  vault write identity/entity-alias name="$i" \
     canonical_id=$VAULT_ENTITY_ID \
     mount_accessor=$LDAP_MOUNT_ACCESSOR \

  vault kv put $KV_PATH/$i/test x=$(uuidgen) y=$(uuidgen)
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

  echo "::::: Logging into Vault as $i"
  VAULT_TOKEN=$(vault login -format=json -method=ldap username=$i password=$i | jq -r .auth.client_token) vault kv list -format=json kv/$i > /dev/null
done

rm -f ~/.vault-token

vault write auth/$LDAP_AUTH_PATH/users/$LDAP_USER_VAULT_ADMIN policies=$LDAP_USER_VAULT_ADMIN,admin

##########
# configure vault-agent

# vault-agent systemd file
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

# vault-agent environment file
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

# vault-agent config
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

chmod 0755 $VAULT_AGENT_PATH/restart-web.sh

cat <<EOF > $VAULT_CERT_DIR/privkey.tpl
{{ with secret "$INTERMEDIATE_CA_NAME/issue/$VAULT_CERT_DOMAIN" "common_name=web.$VAULT_CERT_DOMAIN" }}
{{ .Data.private_key }}
{{ end }}
EOF

cat <<EOF > $VAULT_CERT_DIR/fullchain.tpl
{{ with secret "$INTERMEDIATE_CA_NAME/issue/$VAULT_CERT_DOMAIN" "common_name=web.$VAULT_CERT_DOMAIN" }}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}
{{ end }}
EOF

cd /data && \
  git clone https://github.com/ykhemani/vault-web-app.git web

mkdir -p /data/web && \
  cd /data/$REPODIR/web-app && \
  cp -r * /data/web && \
  cd /data

systemctl daemon-reload && \
  systemctl enable vault-agent && \
  systemctl start vault-agent

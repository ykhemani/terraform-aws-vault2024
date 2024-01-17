## Background
This repo provides a demo environment for showcasing how [HashiCorp](https://hashicorp.com/) [Vault](https://vaultproject.io/) can help you to reduce risk in your operating environment.

The demo environment is provisioned in [AWS](https://aws.com) using [Terraform](https://terraform.io). The demo environment includes:
* Vault Enterprise acting as an identity broker, provider of static secrets and dynamic, short-lived secrets, and encryption as a service.
* [MySQL](https://www.mysql.com/) acting as a database backend for a web application.
* [Apache](https://httpd.apache.org/) web server with [PHP](https://www.php.net/) providing a web application that integrates with the MySQL database to write and retrieve data, and with Vault to protect senstive data using Vault Transit Encryption.
* [https://www.openldap.org/](OpenLDAP) server acting as an Identity Provider (IdP).
* Vault Agent interacting with the Vault cluster to obtain dynamic, short-lived database credentials and PKI certificates for the web application.

## Usage
This demo environment has been designed to minimize dependencies.

### Prerequisites

* A machine image with the required software, built using HashiCorp [Packer](https://packer.io) and [this Packer template](https://github.com/ykhemani/packer-ubuntu-focal).
* [Terraform](https://developer.hashicorp.com/terraform/install) CLI. Testing has been done with version 1.6.5, but other versions of Terraform may also work.
* [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/) for Terraform. Testing has been done with version 5.31.0. The AWS provider will be downloaded automatically from the Terraform Registry when you initialize Terraform in this directory.
* [HCP Provider](https://registry.terraform.io/providers/hashicorp/hcp/latest) for Terraform. Testing has been done with version 0.79.0. The HCP provider will be downloaded automatically from the Terraform Registry when you initialize Terraform in this directory.
* [Local Provider](https://registry.terraform.io/providers/hashicorp/local/) for Terraform. Testing has been done with version 2.4.1. The Local provider will be downloaded automatically from the Terraform Registry when you initialize Terraform in this directory.
* [TLS Provider](https://registry.terraform.io/providers/hashicorp/tls/) for Terraform. Testing has been done with version 4.0.5. The TLS provider will be downloaded automatically from the Terraform Registry when you initialize Terraform in this directory.
* The [vpc](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest) Terraform module. Testing has been done with version 5.4.0 of this module. This module will be downloaded automatically from the Terraform Registry when you initialize Terraform in this directory.

### Note
Please note that we will be running Terraform locally, from the CLI, rather than in Terraform Cloud. The reason is that we generate a Certificate Authority and an ssh private key. The CA cert and ssh private key are rendered as local files that you will use for accessing the resources that are provisioned. These resources can be generated in Terraform Cloud, and you can retrieve them and render them locally, but the approach described above was adopted to minimize dependencies as you render your demo environment.

You may, however, store your Terraform state securely in Terraform Cloud and configure the Terraform workspace to use local execution.

Please also note that all testing of this code has been done in macOS on a Mac with an Apple processor.

### Fork this repo and clone the fork
Start by forking this repo and cloning your fork of this repo.

### Provisioning with Terraform

The Terraform configuration is in the [terraform](terraform) directory. That is where you'll be running Terraform.

#### Terraform variables
Please see [terraform.tfvars.example](terraform.tfvars.example) and [variables.tf](variables.tf) for the Terraform variables you can set. At a minimum, you must set the following Terraform variables:
* `owner_cidr_blocks` - List of CIDR block from which to allow access to the resources provisioned. You may obtain your public IP by running `curl -4 ipconfig.io`.
* `prefix` - Naming prefix.
* `vault_license` - Vault license string. Please contact your HashiCorp account team if you don't have a Vault license.

#### Cloud Credentials
In addition to setting your Terraform variables, set your AWS cloud credentials and HCP credentials as environment variables. The HCP credentials are necessary to identify the machine image registered in your HCP Packer registry.

##### AWS Cloud Credentials
* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_SESSION_TOKEN` # if required for your AWS account

##### HCP Credentials
* `HCP_CLIENT_ID`
* `HCP_CLIENT_SECRET`

#### Run Terraform

```
terraform init     # Intialize Terraform
terraform fmt      # Correct formatting in Terraform configuration files, if needed (optional)
terraform validate # Validate Terraform configuration
terraform plan     # Generate a speculative plan (optional)
terraform apply    # Create / update infrastructure declared in the Terraform configuration
```

#### Example run

<details>
  <summary>Initialize Terraform (`terraform init`)</summary>

```
$ terraform init

Initializing the backend...
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/vpc/aws 5.4.0 for vpc...
- vpc in .terraform/modules/vpc

Initializing provider plugins...
- Finding hashicorp/tls versions matching "~> 4.0"...
- Finding latest version of hashicorp/local...
- Finding hashicorp/aws versions matching ">= 5.0.0, ~> 5.0"...
- Finding hashicorp/hcp versions matching "~> 0.79"...
- Installing hashicorp/local v2.4.1...
- Installed hashicorp/local v2.4.1 (signed by HashiCorp)
- Installing hashicorp/aws v5.31.0...
- Installed hashicorp/aws v5.31.0 (signed by HashiCorp)
- Installing hashicorp/hcp v0.79.0...
- Installed hashicorp/hcp v0.79.0 (signed by HashiCorp)
- Installing hashicorp/tls v4.0.5...
- Installed hashicorp/tls v4.0.5 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```
</details>

<details>
<summary>Check Terraform format (`terraform fmt`)</summary>

There won't be any output if all files are formatted correctly. Any that aren't will be updated with the format corrected. For example:

```
$ terraform fmt
terraform.tfvars
```
</details>

<details>
<summary>Validate the configuration files (`terraform validate`)</summary>
While this isn't strictly necessary, it is good practice.

```
$ terraform validate
Success! The configuration is valid.
```
</details>

<details>
<summary>Generate a speculative plan (`terraform plan`)</summary>

```
$ terraform plan
data.aws_availability_zones.available: Reading...
data.aws_ami.ami: Reading...
data.aws_availability_zones.available: Read complete after 0s [id=us-east-1]
data.aws_ami.ami: Read complete after 0s [id=ami-055744c75048d8296]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_eip.eip will be created
  + resource "aws_eip" "eip" {
      # snip
    }

  # aws_instance.instance will be created
  + resource "aws_instance" "instance" {
      # snip
    }

  # aws_key_pair.ssh will be created
  + resource "aws_key_pair" "ssh" {
      # snip
    }

  # aws_network_interface.nic will be created
  + resource "aws_network_interface" "nic" {
      # snip
    }

  # aws_security_group.sg_egress will be created
  + resource "aws_security_group" "sg_egress" {
      # snip
    }

  # aws_security_group.sg_ingress will be created
  + resource "aws_security_group" "sg_ingress" {
      # snip
    }

  # local_file.ca_cert will be created
  + resource "local_file" "ca_cert" {
      # snip
    }

  # local_file.ssh_private_key will be created
  + resource "local_file" "ssh_private_key" {
      # snip
    }

  # local_file.ssh_public_key will be created
  + resource "local_file" "ssh_public_key" {
      # snip
    }

  # tls_cert_request.wildcard_csr will be created
  + resource "tls_cert_request" "wildcard_csr" {
      # snip
    }

  # tls_locally_signed_cert.wildcard_cert will be created
  + resource "tls_locally_signed_cert" "wildcard_cert" {
      # snip
    }

  # tls_private_key.ca-private-key will be created
  + resource "tls_private_key" "ca-private-key" {
      # snip
    }

  # tls_private_key.ssh will be created
  + resource "tls_private_key" "ssh" {
      # snip
    }

  # tls_private_key.wildcard_private_key will be created
  + resource "tls_private_key" "wildcard_private_key" {
      # snip
    }

  # tls_self_signed_cert.ca-cert will be created
  + resource "tls_self_signed_cert" "ca-cert" {
      # snip
    }

  # module.vpc.aws_default_network_acl.this[0] will be created
  + resource "aws_default_network_acl" "this" {
      # snip
    }

  # module.vpc.aws_default_route_table.default[0] will be created
  + resource "aws_default_route_table" "default" {
      # snip
    }

  # module.vpc.aws_default_security_group.this[0] will be created
  + resource "aws_default_security_group" "this" {
      # snip
    }

  # module.vpc.aws_eip.nat[0] will be created
  + resource "aws_eip" "nat" {
      # snip
    }

  # module.vpc.aws_internet_gateway.this[0] will be created
  + resource "aws_internet_gateway" "this" {
      # snip
    }

  # module.vpc.aws_nat_gateway.this[0] will be created
  + resource "aws_nat_gateway" "this" {
      # snip
    }

  # module.vpc.aws_route.private_nat_gateway[0] will be created
  + resource "aws_route" "private_nat_gateway" {
      # snip
    }

  # module.vpc.aws_route.public_internet_gateway[0] will be created
  + resource "aws_route" "public_internet_gateway" {
      # snip
    }

  # module.vpc.aws_route_table.private[0] will be created
  + resource "aws_route_table" "private" {
      # snip
    }

  # module.vpc.aws_route_table.public[0] will be created
  + resource "aws_route_table" "public" {
      # snip
    }

  # module.vpc.aws_route_table_association.private[0] will be created
  + resource "aws_route_table_association" "private" {
      # snip
    }

  # module.vpc.aws_route_table_association.public[0] will be created
  + resource "aws_route_table_association" "public" {
      # snip
    }

  # module.vpc.aws_subnet.private[0] will be created
  + resource "aws_subnet" "private" {
      # snip
    }

  # module.vpc.aws_subnet.public[0] will be created
  + resource "aws_subnet" "public" {
      # snip
    }

  # module.vpc.aws_vpc.this[0] will be created
  + resource "aws_vpc" "this" {
      # snip
    }

Plan: 30 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + a_hosts_file_entry   = (known after apply)
  + b_connection_strings = {
      + ssh       = (known after apply)
      + vault_url = "https://vault.example.com:8200/"
      + web_url   = "https://web.demo.example.com/"
    }
  + d_public_ip          = (known after apply)
  + e_private_ip         = (known after apply)
  + z_info               = "Your ssh key has been saved as ssh_key, with the corresponding public key saved as ssh_key.pub. The CA cert has been saved as ca.pem. To use this demo environment, please add the hosts_file_entry output to your /etc/hosts file. Please add the CA Cert to your trust store. You may then connect to the ssh environment."

──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply"
now.
```
</details>

<details>
<summary>Provision the resources (`terraform apply`)</summary>

You may use the `-auto-approve` flag for `terraform apply` to skip the interactive approval of plan before applying as we have done below.

```
$ terraform apply -auto-approve
data.aws_availability_zones.available: Reading...
data.aws_ami.ami: Reading...
data.aws_availability_zones.available: Read complete after 0s [id=us-east-1]
data.aws_ami.ami: Read complete after 0s [id=ami-055744c75048d8296]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_eip.eip will be created
  + resource "aws_eip" "eip" {
      # snip
    }

  # aws_instance.instance will be created
  + resource "aws_instance" "instance" {
      # snip
    }

  # aws_key_pair.ssh will be created
  + resource "aws_key_pair" "ssh" {
      # snip
    }

  # aws_network_interface.nic will be created
  + resource "aws_network_interface" "nic" {
      # snip
    }

  # aws_security_group.sg_egress will be created
  + resource "aws_security_group" "sg_egress" {
      # snip
    }

  # aws_security_group.sg_ingress will be created
  + resource "aws_security_group" "sg_ingress" {
      # snip
    }

  # local_file.ca_cert will be created
  + resource "local_file" "ca_cert" {
      # snip
    }

  # local_file.ssh_private_key will be created
  + resource "local_file" "ssh_private_key" {
      # snip
    }

  # local_file.ssh_public_key will be created
  + resource "local_file" "ssh_public_key" {
      # snip
    }

  # tls_cert_request.wildcard_csr will be created
  + resource "tls_cert_request" "wildcard_csr" {
      # snip
    }

  # tls_locally_signed_cert.wildcard_cert will be created
  + resource "tls_locally_signed_cert" "wildcard_cert" {
      # snip
    }

  # tls_private_key.ca-private-key will be created
  + resource "tls_private_key" "ca-private-key" {
      # snip
    }

  # tls_private_key.ssh will be created
  + resource "tls_private_key" "ssh" {
      # snip
    }

  # tls_private_key.wildcard_private_key will be created
  + resource "tls_private_key" "wildcard_private_key" {
      # snip
    }

  # tls_self_signed_cert.ca-cert will be created
  + resource "tls_self_signed_cert" "ca-cert" {
      # snip
    }

  # module.vpc.aws_default_network_acl.this[0] will be created
  + resource "aws_default_network_acl" "this" {
      # snip
    }

  # module.vpc.aws_default_route_table.default[0] will be created
  + resource "aws_default_route_table" "default" {
      # snip
    }

  # module.vpc.aws_default_security_group.this[0] will be created
  + resource "aws_default_security_group" "this" {
      # snip
    }

  # module.vpc.aws_eip.nat[0] will be created
  + resource "aws_eip" "nat" {
      # snip
    }

  # module.vpc.aws_internet_gateway.this[0] will be created
  + resource "aws_internet_gateway" "this" {
      # snip
    }

  # module.vpc.aws_nat_gateway.this[0] will be created
  + resource "aws_nat_gateway" "this" {
      # snip
    }

  # module.vpc.aws_route.private_nat_gateway[0] will be created
  + resource "aws_route" "private_nat_gateway" {
      # snip
    }

  # module.vpc.aws_route.public_internet_gateway[0] will be created
  + resource "aws_route" "public_internet_gateway" {
      # snip
    }

  # module.vpc.aws_route_table.private[0] will be created
  + resource "aws_route_table" "private" {
      # snip
    }

  # module.vpc.aws_route_table.public[0] will be created
  + resource "aws_route_table" "public" {
      # snip
    }

  # module.vpc.aws_route_table_association.private[0] will be created
  + resource "aws_route_table_association" "private" {
      # snip
    }

  # module.vpc.aws_route_table_association.public[0] will be created
  + resource "aws_route_table_association" "public" {
      # snip
    }

  # module.vpc.aws_subnet.private[0] will be created
  + resource "aws_subnet" "private" {
      # snip
    }

  # module.vpc.aws_subnet.public[0] will be created
  + resource "aws_subnet" "public" {
      # snip
    }

  # module.vpc.aws_vpc.this[0] will be created
  + resource "aws_vpc" "this" {
      # snip
    }

Plan: 30 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + a_hosts_file_entry   = (known after apply)
  + b_connection_strings = {
      + ssh       = (known after apply)
      + vault_url = "https://vault.example.com:8200/"
      + web_url   = "https://web.demo.example.com/"
    }
  + d_public_ip          = (known after apply)
  + e_private_ip         = (known after apply)
  + z_info               = "Your ssh key has been saved as ssh_key, with the corresponding public key saved as ssh_key.pub. The CA cert has been saved as ca.pem. To use this demo environment, please add the hosts_file_entry output to your /etc/hosts file. Please add the CA Cert to your trust store. You may then connect to the ssh environment."
tls_private_key.ca-private-key: Creating...
tls_private_key.wildcard_private_key: Creating...
tls_private_key.ssh: Creating...
module.vpc.aws_vpc.this[0]: Creating...
tls_private_key.ca-private-key: Creation complete after 1s [id=7dea8490788f57139123422837d46b924c9cfe4e]
tls_self_signed_cert.ca-cert: Creating...
tls_self_signed_cert.ca-cert: Creation complete after 0s [id=268143976041273068407462725771822313374]
local_file.ca_cert: Creating...
local_file.ca_cert: Creation complete after 0s [id=e2df1ba2361a63b76550f5e257f92664652fd281]
tls_private_key.wildcard_private_key: Creation complete after 2s [id=f224c3fe61bf7a1de1c3e3e30e0dfaf5efcc45d9]
tls_cert_request.wildcard_csr: Creating...
tls_cert_request.wildcard_csr: Creation complete after 0s [id=0493eac7579600f1ba67beca1238ef3419f5f57e]
tls_locally_signed_cert.wildcard_cert: Creating...
tls_locally_signed_cert.wildcard_cert: Creation complete after 0s [id=244831356383860679381816770268193643526]
tls_private_key.ssh: Creation complete after 3s [id=2ac7ba491475bf37d1edb828d38a4b7032ef9c50]
aws_key_pair.ssh: Creating...
local_file.ssh_private_key: Creating...
local_file.ssh_public_key: Creating...
local_file.ssh_public_key: Creation complete after 0s [id=d9415dee553542627b95515905a0ff844785f1bb]
local_file.ssh_private_key: Creation complete after 0s [id=3b2c026a273429591ddcfb5f853a1b89c4fdc0f0]
aws_key_pair.ssh: Creation complete after 0s [id=yash-vault-demo-rig-key]
module.vpc.aws_vpc.this[0]: Still creating... [10s elapsed]
module.vpc.aws_vpc.this[0]: Creation complete after 12s [id=vpc-02b9f53351322fc08]
module.vpc.aws_route_table.public[0]: Creating...
module.vpc.aws_default_security_group.this[0]: Creating...
module.vpc.aws_route_table.private[0]: Creating...
module.vpc.aws_internet_gateway.this[0]: Creating...
module.vpc.aws_subnet.private[0]: Creating...
aws_security_group.sg_egress: Creating...
aws_security_group.sg_ingress: Creating...
module.vpc.aws_subnet.public[0]: Creating...
module.vpc.aws_default_route_table.default[0]: Creating...
module.vpc.aws_default_network_acl.this[0]: Creating...
module.vpc.aws_default_route_table.default[0]: Creation complete after 0s [id=rtb-07b57b2de6755cc99]
module.vpc.aws_route_table.public[0]: Creation complete after 0s [id=rtb-09742eef697eceae1]
module.vpc.aws_internet_gateway.this[0]: Creation complete after 1s [id=igw-0a530c368c10bd56e]
module.vpc.aws_route.public_internet_gateway[0]: Creating...
module.vpc.aws_eip.nat[0]: Creating...
module.vpc.aws_route_table.private[0]: Creation complete after 1s [id=rtb-01ced6133adc4228a]
module.vpc.aws_subnet.public[0]: Creation complete after 1s [id=subnet-0405e3e23c829e6bc]
module.vpc.aws_route_table_association.public[0]: Creating...
module.vpc.aws_subnet.private[0]: Creation complete after 1s [id=subnet-070a9ff96e9a72a94]
module.vpc.aws_route_table_association.private[0]: Creating...
module.vpc.aws_route_table_association.public[0]: Creation complete after 0s [id=rtbassoc-096fcd8209d21a441]
module.vpc.aws_route.public_internet_gateway[0]: Creation complete after 0s [id=r-rtb-09742eef697eceae11080289494]
module.vpc.aws_route_table_association.private[0]: Creation complete after 0s [id=rtbassoc-031e7cd29baa2d9c9]
module.vpc.aws_eip.nat[0]: Creation complete after 0s [id=eipalloc-0f8e3ccea0e69ae3c]
module.vpc.aws_nat_gateway.this[0]: Creating...
module.vpc.aws_default_network_acl.this[0]: Creation complete after 1s [id=acl-0d7745138e448cae4]
module.vpc.aws_default_security_group.this[0]: Creation complete after 2s [id=sg-07bc31b251793e759]
aws_security_group.sg_egress: Creation complete after 2s [id=sg-0add688d47ff07790]
aws_security_group.sg_ingress: Creation complete after 2s [id=sg-07e5a9c3cfa9b5f35]
aws_network_interface.nic: Creating...
aws_network_interface.nic: Creation complete after 1s [id=eni-0d615eb5c609b6333]
aws_eip.eip: Creating...
aws_instance.instance: Creating...
aws_eip.eip: Creation complete after 2s [id=eipalloc-02f311a0e99b8204d]
module.vpc.aws_nat_gateway.this[0]: Still creating... [10s elapsed]
aws_instance.instance: Still creating... [10s elapsed]
aws_instance.instance: Creation complete after 14s [id=i-044b057ba8e01f2f0]
module.vpc.aws_nat_gateway.this[0]: Still creating... [20s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [30s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [40s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [50s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [1m0s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [1m10s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [1m20s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [1m30s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [1m40s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [1m50s elapsed]
module.vpc.aws_nat_gateway.this[0]: Creation complete after 1m55s [id=nat-04491c85642b84fba]
module.vpc.aws_route.private_nat_gateway[0]: Creating...
module.vpc.aws_route.private_nat_gateway[0]: Creation complete after 1s [id=r-rtb-01ced6133adc4228a1080289494]

Apply complete! Resources: 30 added, 0 changed, 0 destroyed.

Outputs:

a_hosts_file_entry = "44.219.133.21 vault.example.com mysql.example.com web.demo.example.com"
b_connection_strings = {
  "ssh" = "ssh -i ./ssh_key ubuntu@44.219.133.21"
  "vault_url" = "https://vault.example.com:8200/"
  "web_url" = "https://web.demo.example.com/"
}
d_public_ip = "44.219.133.21"
e_private_ip = "10.0.101.151"
z_info = "Your ssh key has been saved as ssh_key, with the corresponding public key saved as ssh_key.pub. The CA cert has been saved as ca.pem. To use this demo environment, please add the hosts_file_entry output to your /etc/hosts file. Please add the CA Cert to your trust store. You may then connect to the ssh environment."
```
</details>

### Interact with Demo Environment

When you provision the environment with Terraform, you'll be provided with the following outputs:
* `a_hosts_file_entry`
* `b_connection_strings`->`ssh`
* `b_connection_strings`->`vault_url`
* `b_connection_strings`->`web_url`

Add the `a_hosts_file_entry` to your `/etc/hosts` file to resolve the `vault_url` and `web_url` on your machine.

Use the `b_connection_strings`->`ssh` output to connect to the provisioned instance.

#### Add the CA Cert to your trust store
This is rendered as `ca.pem` in the `terraform` directory.

#### Interact with the target environment in your browser using:

* `b_connection_strings`->`vault_url`
* `b_connection_strings`->`web_url`

You may log into the Vault cluster using LDAP authentication. Use the admin user to login. By default, the username and password for the admin user is `yash`.

#### SSH to target instance and verify the installation

```
# ssh to target instance
ssh -i ./ssh_key ubuntu@<target instance>

# become root using sudo
sudo su - 

# examine the cloud-init output log
tail -f /var/log/cloud-init-output.log

# examine docker containers (there should be 4: vault, mysql, openldap, vault-agent)
docker ps -a

# examine docker logs
cd /data/docker-demo-stack && docker-compose logs -f

# examine OpenLDAP server
ldapsearch -x -H ldaps://openldap.example.com -b dc=example,dc=com \
  -D "cn=admin,dc=example,dc=com" -w password

# Examine Vault Agent status
systemctl status vault-agent

# Examine Vault Server
vault status
vault secrets list
vault auth list
vault policy list

# Obtain short-lived dynamic database credentials (MySQL)
vault read mysql-demo/creds/mysql-web-role

# Obtain short-lived dynamic database credentials (MongoDB)
vault read mongodb-demo/creds/mysql-web-role

# Validate LDAP auth
vault login -method=ldap username=john password=john
```

More to come here soon.

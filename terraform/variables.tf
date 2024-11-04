variable "global_tags" {
  type        = map(string)
  description = "Default tags to apply to AWS resources. Meant to be defined via Variable Sets in your Terraform Cloud organization, but can be overriden if needed."
  default     = {}
}

variable "local_tags" {
  type        = map(string)
  description = "Local tags to apply to cloud resources."
  default     = {}
}

variable "region" {
  type        = string
  description = "AWS Region in which to deploy our instance."
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC."
  default     = "10.0.0.0/16"
}

variable "owner_cidr_blocks" {
  type        = list(string)
  description = "Owner CIDR block to allow access from owner's subnet."
  default     = []
}

variable "prefix" {
  type        = string
  description = "Naming prefix"
}

variable "hcp_packer_image_bucket_name" {
  type        = string
  description = "The slug of the HCP Packer Registry image bucket to pull from."
  default     = ""
}

variable "hcp_packer_image_channel" {
  type        = string
  description = "The channel that points to the version of the image you want."
  default     = ""
}

# variable "ami_filter" {
#   type        = string
#   description = "AMI filter - e.g. ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
#   default     = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
# }

# variable "ami_owner" {
#   type        = string
#   description = "Owner of AMI - e.g. Canonical (for Ubuntu images) is 099720109477. RedHat is 309956199498."
#   default     = "099720109477"
# }

variable "ami_id" {
  type        = string
  description = "Optional AMI ID - use this if not blank string, otherwise use AMI per ami_filter and ami_owner."
  default     = ""
}

variable "instance_type" {
  type        = string
  description = "Instance size."
  default     = "m5.large"
}

variable "root_volume_type" {
  type        = string
  description = "Root volume type."
  default     = "gp3"
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GB."
  default     = 50
}

variable "instance_security_group_ids" {
  type        = list(string)
  description = "List of additional security group ID's to apply to the instance."
  default     = []
}

variable "userdata_templatefile" {
  type        = string
  description = "Name of userdata template file."
  default     = "userdata.sh.tpl"
}

variable "gitrepo" {
  type        = string
  description = "Public git repo from which to clone (use https rather than ssh)."
  default     = "https://github.com/ykhemani/terraform-aws-vault2024.git"
}

variable "repodir" {
  type        = string
  description = "Name of directory into which to clone the gitrepo (under the /data directory.)"
  default     = "vault-demo-rig"
}

# KMS
variable "vault_kms_key_rotate" {
  type        = bool
  description = "Whether to rotate Vault KMS key."
  default     = false
}

variable "vault_kms_key_deletion_days" {
  type        = number
  description = "Number of days to wait before deleting Vault KMS key."
  default     = 7
}

#-------------------------------------------------------------------------
# Vault
#-------------------------------------------------------------------------

variable "vault_container_image" {
  type        = string
  description = "Vault container image."
  default     = "hashicorp/vault-enterprise:1.16.7-ent"
}

variable "vault_transform_fpe" {
  type        = bool
  description = "Whether to configure the Transform secret engine format preserving encryption (FPE) demo."
  default     = true
}

variable "vault_transform_tokenization" {
  type        = bool
  description = "Whether to configure the Transform secret engine tokenization demo."
  default     = true
}

variable "ssh_import_id" {
  type        = string
  description = "Name of id from which to import ssh keys. e.g. gh:ykhemani. The corresponding ssh keys will have root access to the instance."
  default     = ""
}

variable "domain" {
  type        = string
  description = "Domain"
  default     = "example.com"
}

variable "vault_license" {
  type        = string
  description = "Vault license"
}

variable "cert_dir" {
  type        = string
  description = "Location for CA and certificates"
  default     = "/data/certs"
}

# Certificate Authority
variable "ca_country" {
  type        = string
  description = "Certificate Authority (CA) Country."
  default     = "US"
}

variable "ca_state" {
  type        = string
  description = "CA State."
  default     = "California"
}

variable "ca_locale" {
  type        = string
  description = "CA Locale."
  default     = "San Francisco"
}

variable "ca_org" {
  type        = string
  description = "CA Organization."
  default     = "HashiCorp"
}

variable "ca_ou" {
  type        = string
  description = "CA Organizational Unit."
  default     = "HashiCorp Network Operations Center"
}

variable "ca_common_name" {
  type        = string
  description = "CA Common Name (CN)."
  default     = "HashiCorp Certificate Authority"
}

variable "ca_cert_validity" {
  type        = number
  description = "CA Certificate validity period in hours."
  default     = 87600 # 10 years  
}

# Certificate
variable "cert_country" {
  type        = string
  description = "Certificate Country."
  default     = "US"
}

variable "cert_state" {
  type        = string
  description = "Certificate State."
  default     = "California"
}

variable "cert_locale" {
  type        = string
  description = "Certificate Locale."
  default     = "San Francisco"
}

variable "cert_org" {
  type        = string
  description = "Certificate Organization."
  default     = "HashiCorp"
}

variable "cert_ou" {
  type        = string
  description = "Certificate Organizational Unit."
  default     = "HashiCorp Network Operations Center"
}

variable "cert_validity" {
  type        = number
  description = "Certificate validity period in hours."
  default     = 8760 # 1 year
}

variable "namespaces" {
  type        = string
  description = "List of namespaces to create."
  default     = "bu0,bu1,bu2,bu3,bu4,bu5"
}

variable "namespace_count" {
  type        = number
  description = "Number of namespaces to create."
  default     = 10
}

variable "ldap_user_count" {
  type        = number
  description = "Number of LDAP users to create."
  default     = 20
}

variable "ldap_user_vault_admin" {
  type        = string
  description = "LDAP user to be assigned vault admin policy."
  default     = "yash"
}

variable "stop_after_starting_vault" {
  type        = bool
  description = "Whether to stop bootstrap after starting vault."
  default     = false
}


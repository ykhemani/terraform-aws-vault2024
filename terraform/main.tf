provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

locals {
  tags = merge(
    var.global_tags,
    var.local_tags
  )

  private_subnets = [cidrsubnet(var.vpc_cidr, 8, 1)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 8, 101)]

  ldap_users = join(",", concat([var.ldap_user_vault_admin], random_pet.ldap_users[*].id))
  namespaces = join(",", random_pet.namespaces[*].id)
}

# HCP Packer Image
data "hcp_packer_artifact" "image" {
  bucket_name  = var.hcp_packer_image_bucket_name
  channel_name = var.hcp_packer_image_channel
  platform     = "aws"
  region       = var.region
}

# Certificate Authority
# ca private key
resource "tls_private_key" "ca-private-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ca cert
resource "tls_self_signed_cert" "ca-cert" {
  private_key_pem       = tls_private_key.ca-private-key.private_key_pem
  validity_period_hours = var.ca_cert_validity
  is_ca_certificate     = true

  subject {
    common_name         = "${var.domain} Demo Root Certificate Authority"
    country             = var.ca_country
    province            = var.ca_state
    locality            = var.ca_locale
    organization        = var.ca_org
    organizational_unit = var.ca_ou

  }
  allowed_uses = [

    "digital_signature",
    "key_encipherment",
    "data_encipherment",
    "cert_signing",
    "server_auth",
    "client_auth"
  ]
}

# ssh private key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = "${var.prefix}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

# wildcard private key
resource "tls_private_key" "wildcard_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# wildcard csr
resource "tls_cert_request" "wildcard_csr" {
  private_key_pem = tls_private_key.wildcard_private_key.private_key_pem

  subject {
    common_name         = "*.${var.domain}"
    country             = var.cert_country
    province            = var.cert_state
    locality            = var.cert_locale
    organization        = var.cert_org
    organizational_unit = var.cert_ou
  }

  dns_names = [
    "*.${var.domain}",
  ]

  ip_addresses = ["127.0.0.1", aws_eip.eip.public_ip]
}

# wildcard cert
resource "tls_locally_signed_cert" "wildcard_cert" {
  cert_request_pem   = tls_cert_request.wildcard_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.ca-private-key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca-cert.cert_pem

  is_ca_certificate = true

  validity_period_hours = var.cert_validity

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth",

    "cert_signing",
    "crl_signing",
    "ocsp_signing"

  ]
}

# VPC
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "${var.prefix}-vpc"
  cidr = var.vpc_cidr

  azs                    = [data.aws_availability_zones.available.names[0]]
  private_subnets        = local.private_subnets
  public_subnets         = local.public_subnets
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true
}

# Security Groups

resource "aws_security_group" "sg_ingress" {
  name        = "${var.prefix}_ingress_sg"
  description = "${var.prefix} Ingress Security Group"
  vpc_id      = module.vpc.vpc_id

  # owner cidr blocks
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.owner_cidr_blocks
  }

  # vpc cidr block
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  tags = {
    Name = "${var.prefix}_ingress_sg"
  }
}

resource "aws_security_group" "sg_egress" {
  name        = "${var.prefix}_egress_sg"
  description = "${var.prefix} Egress Security Group"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}_egress_sg"
  }
}

# Network Interface
resource "aws_network_interface" "nic" {
  subnet_id = element(module.vpc.public_subnets, 1)
  security_groups = concat(
    [
      aws_security_group.sg_ingress.id,
      aws_security_group.sg_egress.id
    ],
    var.instance_security_group_ids
  )
}

# ldap users
resource "random_pet" "ldap_users" {
  count  = var.ldap_user_count
  length = 1
}

# namespaces
resource "random_pet" "namespaces" {
  count  = var.namespace_count
  length = 1
}

# bootstrap secrets
resource "aws_secretsmanager_secret" "bootstrap-secrets" {
  name = "${var.prefix}-bootstrap-secrets-${random_string.suffix.result}"

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "bootstrap-secrets" {
  secret_id = aws_secretsmanager_secret.bootstrap-secrets.id
  secret_string = jsonencode(
    {
      domain                = var.domain,
      vault_license         = var.vault_license,
      namespaces            = local.namespaces,
      ldap_users            = local.ldap_users
      ldap_user_vault_admin = var.ldap_user_vault_admin,
      cert_dir              = var.cert_dir,
      ca_cert               = tls_self_signed_cert.ca-cert.cert_pem,
      wildcard_private_key  = tls_private_key.wildcard_private_key.private_key_pem,
      wildcard_cert         = tls_locally_signed_cert.wildcard_cert.cert_pem,
      ssh_import_id         = var.ssh_import_id,
      gitrepo               = var.gitrepo,
      repodir               = var.repodir,
    }
  )
}

data "aws_region" "current" {}

resource "aws_iam_role_policy" "iam-policy" {
  name   = "${var.prefix}-iam-role-policy-${data.aws_region.current.name}"
  role   = aws_iam_role.instance_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Effect": "Allow",
      "Resource": "${aws_secretsmanager_secret.bootstrap-secrets.arn}"
    }
  ]
}
EOF
}

# KMS
resource "aws_kms_key" "vault" {
  description             = "KMS key for ${var.prefix} Vault cluster"
  enable_key_rotation     = var.vault_kms_key_rotate
  deletion_window_in_days = var.vault_kms_key_deletion_days

  tags = {
    Name = "${var.prefix}-vault-kms-key-${random_string.suffix.result}"
  }
}

resource "random_string" "suffix" {
  length  = 4
  special = false
}

# IAM
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "iam-policy-document" {
  statement {
    sid       = "VaultGetSecrets"
    effect    = "Allow"
    resources = [aws_secretsmanager_secret.bootstrap-secrets.arn]
    actions = [
      "secretsmanager:GetSecretValue",
    ]
  }

  statement {
    sid       = "VaultKMSUnseal"
    effect    = "Allow"
    resources = [aws_kms_key.vault.arn]
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateRandom"
    ]
  }
}

resource "aws_iam_role" "instance_role" {
  name               = "${var.prefix}-iam-role-${data.aws_region.current.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "vault-demo-iam-role-policy" {
  name   = "${var.prefix}-iam-role-policy"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.iam-policy-document.json
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.prefix}-instance-profile-${data.aws_region.current.name}"
  role = aws_iam_role.instance_role.name
}


resource "aws_eip" "eip" {
  network_interface = aws_network_interface.nic.id
}

resource "aws_instance" "instance" {
  #subnet_id = element(module.vpc.public_subnets, 1)
  # associate_public_ip_address = true
  # vpc_security_group_ids = concat(
  #   [
  #     aws_security_group.sg_ingress.id,
  #     aws_security_group.sg_egress.id
  #   ],
  #   var.instance_security_group_ids
  # )
  network_interface {
    network_interface_id = aws_network_interface.nic.id
    device_index         = 0
  }

  # ami                  = "ami-0d617e077b72bc526"
  ami = data.hcp_packer_artifact.image.external_identifier # hcp packer image
  # ami                  = local.ami_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  key_name             = aws_key_pair.ssh.key_name
  root_block_device {
    volume_type = var.root_volume_type
    volume_size = var.root_volume_size
  }

  user_data_base64 = base64gzip(templatefile("${path.module}/templates/${var.userdata_templatefile}", {
    secret_arn                   = aws_secretsmanager_secret.bootstrap-secrets.arn,
    kms_key_id                   = aws_kms_key.vault.key_id,
    region                       = data.aws_region.current.name,
    gitrepo                      = var.gitrepo,
    repodir                      = var.repodir,
    stop_after_starting_vault    = var.stop_after_starting_vault
    vault_container_image        = var.vault_container_image
    vault_transform_fpe          = var.vault_transform_fpe
    vault_transform_tokenization = var.vault_transform_tokenization
  }))

  tags = merge(
    { Name = "${var.prefix}-demo" },
    local.tags
  )
}

resource "local_file" "ca_cert" {
  content         = tls_self_signed_cert.ca-cert.cert_pem
  filename        = "${path.module}/ca.pem"
  file_permission = "0644"
}

resource "local_file" "ssh_private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/ssh_key"
  file_permission = "0600"
}

resource "local_file" "ssh_public_key" {
  content         = tls_private_key.ssh.public_key_openssh
  filename        = "${path.module}/ssh_key.pub"
  file_permission = "0644"
}

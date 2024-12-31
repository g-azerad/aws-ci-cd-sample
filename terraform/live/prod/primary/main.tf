terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  required_version = ">= 1.10.0"
}

# Getting AWS provider configuration from variables
provider "aws" {
  region                   = var.region
  # shared_config_files      = ["../../../.aws/config"]
  # shared_credentials_files = ["../../../.aws/credentials"]
  # profile = var.profile
}

# Retrieving account information
data "aws_caller_identity" "current" {}

# Defining the SSH key to use with EC2 instances
resource "aws_key_pair" "access_key" {
  key_name   = "access_key"
  public_key = var.ssh_public_key
}

# Get server public IP to set Bastion SSH access
data "external" "config" {
  program = ["../../../scripts/get_public_ip.sh"]
}

# Importing network module to create network configuration
module "network" {
  source = "../../../modules/network"
  name   = var.environment
}

# Setting the ingress rule for bastion SSH access
resource "aws_vpc_security_group_ingress_rule" "bastion_sg" {
  security_group_id = module.network.bastion_sg_id

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = "${data.external.config.result["public_ip"]}/32"
}

# Creating the SSH bastion
module "bastion" {
  source = "../../../modules/bastion"
  subnet_id         = module.network.public_subnet_id
  bastion_sg_id     = module.network.bastion_sg_id
  name              = "${var.environment}-bastion"
  key_name          = aws_key_pair.access_key.key_name
}

# Importing rds module to create RDS PostgreSQL database
module "rds" {
  source                     = "../../../modules/rds"
  region                     = var.region
  vpc_id                     = module.network.vpc_id
  security_group_id          = module.network.database_sg_id
  private_subnet_ids         = [module.network.private_subnet_id, module.network.private_subnet_bkp_id]
  allocated_storage          = var.db_allocated_storage
  engine_version             = var.postgresql_version
  backup_retention_period    = var.backup_retention_period
  db_name                    = var.db_name
  db_master_username         = var.db_master_username
  db_port                    = var.db_port
  db_master_user_secret_name = var.db_master_user_secret_name
  public_subnet_ip_range     = module.network.public_subnet_cidr
  account_id                 = data.aws_caller_identity.current.account_id
}

# Creating the Lambda to run the API
module "lambda" {
  source               = "../../../modules/lambda"
  api_name             = "${var.environment}-api"
  public_subnet_id     = module.network.public_subnet_id
  security_group_id    = module.network.instance_sg_id
  lambda_zip_file      = var.lambda_zip_file
  dependencies_package = var.dependencies_package
  db_user_secret_name  = var.db_user_secret_name
  db_name              = var.db_name
  db_username          = var.db_username
  db_port              = var.db_port
  db_host              = module.rds.db_endpoint
}
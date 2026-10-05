locals {
  name = "${var.name}-${var.environment}"

  # Static AZ suffixes keep `validate` and `plan` free of AWS API calls; switch to the
  # aws_availability_zones data source once credentials are available.
  azs = [for s in slice(["a", "b", "c", "d"], 0, var.az_count) : "${var.region}${s}"]

  tags = {
    Project     = var.name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs

  # /20 per subnet: public in 0..n-1, private in 4..4+n-1, database in 8..8+n-1
  public_subnets   = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 4)]
  database_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  create_database_subnet_group = true

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws
module "web_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name        = "${local.name}-web"
  description = "HTTPS in from anywhere, everything out."
  vpc_id      = module.vpc.vpc_id

  ingress_rules = {
    https = {
      description = "HTTPS"
      cidr_ipv4   = "0.0.0.0/0"
      from_port   = 443
      to_port     = 443
    }
  }

  egress_rules = {
    all = {
      description = "All traffic"
      cidr_ipv4   = "0.0.0.0/0"
      ip_protocol = "-1"
    }
  }
}

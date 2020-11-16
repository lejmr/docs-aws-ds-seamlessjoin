provider "aws" {
  region = "${var.region}"
}



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.64.0"
  # insert the 8 required variables here


  name = "DirectoryJoining"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway     = true
  enable_vpn_gateway     = true
  one_nat_gateway_per_az = false
  single_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
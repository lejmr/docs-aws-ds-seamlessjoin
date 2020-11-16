resource "aws_directory_service_directory" "simpleds" {
  name     = "ad.exaple.com"
  password = "SuperSecretPassw0rd"
  size     = "Small"
  type     = "SimpleAD"

  vpc_settings {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = module.vpc.private_subnets
  }
}

resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name_servers = aws_directory_service_directory.simpleds.dns_ip_addresses
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = module.vpc.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
}
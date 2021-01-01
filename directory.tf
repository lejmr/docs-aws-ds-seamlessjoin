resource "aws_directory_service_directory" "simpleds" {
  name     = var.directory_name
  password = var.directory_password
  size     = "Small"
  type     = "SimpleAD"
  // In case MS AD 
  // type = "MicrosoftAD"
  short_name = var.short_name

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
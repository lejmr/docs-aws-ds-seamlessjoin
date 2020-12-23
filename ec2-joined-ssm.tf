// DEMO node
data "aws_ami" "ubuntu1804" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

data "aws_ami" "ubuntu2004" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow RDP inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_instance" "ssm-ubuntu1" {
  ami                    = data.aws_ami.ubuntu1804.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.domain_joined.name
  key_name               = aws_key_pair.sshkey.key_name
  user_data              = <<EOF
#cloud-config
hostname: ubuntu1.${var.directory_name}
fqdn: ubuntu1.${var.directory_name}
EOF
  tags = {
    Name = "ubuntu1.${var.directory_name}"
  }
}


resource "aws_instance" "ssm-ubuntu2" {
  ami                    = data.aws_ami.ubuntu2004.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.domain_joined.name
  key_name               = aws_key_pair.sshkey.key_name
  user_data              = <<EOF
#cloud-config
hostname: ubuntu2.${var.directory_name}
fqdn: ubuntu2.${var.directory_name}
EOF
  tags = {
    Name = "ubuntu2.${var.directory_name}"
  }
}

resource "aws_ssm_association" "ubuntu" {
  name = "${var.short_name}-JoinDirectoryServiceDomain"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.ssm-ubuntu1.id, aws_instance.ssm-ubuntu2.id]
  }

  parameters = {
    directoryId   = aws_directory_service_directory.simpleds.id
    directoryName = var.directory_name

    // This is not really necessary, as DHCP options is added (however, there are some caveats)
    dnsIpAddresses = join(" ", aws_directory_service_directory.simpleds.dns_ip_addresses)
  }
}

// Management node
data "aws_ami" "win2019" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["801119661308"]
}

resource "aws_security_group" "allow_rdp" {
  name        = "allow_rdp"
  description = "Allow RDP inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "RDP from VPC"
    from_port   = 3389
    to_port     = 3389
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
    Name = "allow_rdp"
  }
}

// IAM 

resource "aws_iam_instance_profile" "domain_joined" {
  name = "ExampleDomainJoinedServer"
  role = aws_iam_role.domain_joined.name
}

resource "aws_iam_role" "domain_joined" {
  name = "ExampleDomainJoinedServer"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
  role       = aws_iam_role.domain_joined.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "AmazonSSMDirectoryServiceAccess" {
  role       = aws_iam_role.domain_joined.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
}

// Computer
data "template_file" "ec2-management" {
  template = <<-EOF
  <powershell>
  ADD-WindowsFeature RSAT-Role-Tools
  </powershell>
  EOF

}

resource "aws_instance" "management" {
  ami                    = data.aws_ami.win2019.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_rdp.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.domain_joined.name
  user_data              = data.template_file.ec2-management.rendered
  key_name               = aws_key_pair.sshkey.key_name
  tags = {
    Name = "Management node"
  }

  depends_on = [
    aws_vpc_dhcp_options_association.dns_resolver
  ]
}

resource "aws_ssm_association" "win-join" {
  name = "AWS-JoinDirectoryServiceDomain"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.management.id]
  }

  parameters = {
    directoryId   = aws_directory_service_directory.simpleds.id
    directoryName = var.directory_name
    // dnsIpAddresses = join("\n", aws_directory_service_directory.simpleds.dns_ip_addresses)
    // dnsIpAddresses = aws_directory_service_directory.simpleds.dns_ip_addresses
  }
}
resource "aws_instance" "lambda-ubuntu" {
    count = 2
  ami                    = data.aws_ami.ubuntu1804.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.domain_joined.name
  key_name               = aws_key_pair.sshkey.key_name
  user_data              = <<EOF
#cloud-config
hostname: lubuntu${count.index}.${var.directory_name}
fqdn: lubuntu${count.index}.${var.directory_name}
EOF
  tags = {
    Name = "lubuntu${count.index}.${var.directory_name}"
    "Domain:Join" = "true"
  }
}
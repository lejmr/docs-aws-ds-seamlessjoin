resource "null_resource" "install_python_dependencies" {
  provisioner "local-exec" {
    command = "bash ${path.module}/function/create_pkg.sh"

    environment = {
      runtime  = "python3"
      path_cwd = "${path.module}/function"
    }
  }
}

data "archive_file" "create_dist_pkg" {
  depends_on  = ["null_resource.install_python_dependencies"]
  source_dir  = "${path.module}/function/lambda_dist_pkg/"
  output_path = "lambda.zip"
  type        = "zip"
}

resource "aws_security_group" "lambda" {
  name        = "lambda"
  description = "Only empty SG"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda"
  }
}

resource "aws_lambda_function" "lambda_joiner" {
  filename      = "lambda.zip"
  function_name = "${var.short_name}-JoinDirectoryServiceDomain"
  role          = aws_iam_role.lambda_joiner.arn
  handler       = "main.lambda_handler"

  source_code_hash = "${data.archive_file.create_dist_pkg.output_base64sha256}"
  runtime          = "${var.runtime}"
  timeout          = 300

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [ aws_security_group.lambda.id ]
  }

  environment {
    variables = {
      directoryId   = aws_directory_service_directory.simpleds.id
      directoryOU   = var.basedn
      join_document = aws_ssm_document.join.name
      ds_region     = var.region
      ldap_host     = var.directory_name
      proto         = var.ldap_proto
    }
  }
}

### Core password - needs to be set manually
resource "aws_secretsmanager_secret" "technical-account" {
  name = "aws/directory-services/${aws_directory_service_directory.simpleds.id}/seamless-domain-join"
  recovery_window_in_days = 30
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id     = aws_secretsmanager_secret.technical-account.id
  secret_string = <<EOL
{
  "awsSeamlessDomainUsername": "Administrator",
  "awsSeamlessDomainPassword": "${var.directory_password}"
}
EOL
}

// Policy allowing read of the password
resource "aws_iam_policy" "secret" {
  name        = "${var.short_name}GetDsPassword"
  path        = "/"
  description = "Policy allowing read credentials for directory service"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": [
                "${aws_secretsmanager_secret.technical-account.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "secret" {
  role       = "${aws_iam_role.lambda_joiner.name}"
  policy_arn = "${aws_iam_policy.secret.arn}"
}
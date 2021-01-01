resource "aws_iam_role" "lambda_joiner" {
  name = "${var.short_name}LambdaJoiner"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_execution" {
  role       = "${aws_iam_role.lambda_joiner.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# This is a non-sense from the security perspective, but there is NO way how to restrict the 
# lambda realm, i.e., limit which subnets can be affected
resource "aws_iam_role_policy_attachment" "lambda_vpcaccess" {
  role       = "${aws_iam_role.lambda_joiner.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "describe_resources" {
  name        = "${var.short_name}DescribeEc2andDs"
  path        = "/"
  description = "Allows to describe related directory services"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ssm:CreateAssociation",
                "ds:DescribeDirectories"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "describe_resources" {
  role       = "${aws_iam_role.lambda_joiner.name}"
  policy_arn = "${aws_iam_policy.describe_resources.arn}"
}
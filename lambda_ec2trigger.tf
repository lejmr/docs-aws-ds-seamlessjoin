resource "aws_cloudwatch_event_rule" "lambda_rule" {
  name        = "${var.short_name}-JoinDirectoryServiceDomain"
  description = "Captures notifications of EC2 being started"

  event_pattern = <<EOF
{
  "source": [
    "aws.ec2"
  ],
  "detail-type": [
    "EC2 Instance State-change Notification"
  ],
  "detail": {
    "state": [
      "terminated",
      "pending"
    ]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda_joiner" {
  arn       = "${aws_lambda_function.lambda_joiner.arn}"
  rule      = "${aws_cloudwatch_event_rule.lambda_rule.id}"
  target_id = "Ec2StateChange"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_handle_function" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda_joiner.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.lambda_rule.arn}"
}
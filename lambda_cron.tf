resource "aws_cloudwatch_event_rule" "lambda_rule_cron" {
  name                = "${var.short_name}-JoinDirectoryServiceDomain-cron"
  description         = "Triggers peridical cleaning"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_joiner_cron" {
  arn       = "${aws_lambda_function.lambda_joiner.arn}"
  rule      = "${aws_cloudwatch_event_rule.lambda_rule_cron.id}"
  target_id = "PeriodicalCleaning"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_start_cleaning" {
  statement_id  = "AllowExecutionFromCloudWatchCron"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda_joiner.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.lambda_rule_cron.arn}"
}
resource "aws_sns_topic" "AmiBuilderNotificationTopic" {
  name = "AmiBuilder-Notify"
}

resource "aws_sqs_queue" "amibuilder_updates_queue" {
  name = "amibuilder-updates-queue"
}

resource "aws_sns_topic_subscription" "amibuilder_updates_sqs_target" {
  topic_arn = "${aws_sns_topic.user_updates.arn}"
  protocol  = "sqs"
  endpoint  = "${aws_sqs_queue.user_updates_queue.arn}"
}

#  Alarma que vigila la salud del pipeline: un mensaje en la DLQ es una lectura que falló
# `maxReceiveCount` veces y no se pudo guardar.
resource "aws_cloudwatch_metric_alarm" "dlq_has_messages" {
  alarm_name        = "${var.name_prefix}-dlq-con-mensajes"
  alarm_description = "Hay lecturas que fallaron y no se guardaron"
  namespace   = "AWS/SQS"
  metric_name = "ApproximateNumberOfMessagesVisible"
  dimensions = {
    QueueName = var.dlq_queue_name
  }

  # Cuándo salta: si en una medición de 60 s el máximo es 1 o más. Con un solo mensaje ya hay
  # un problema, así que alcanza una medición (evaluation_periods = 1). "Maximum" y no
  # "SampleCount": SampleCount cuenta cuántas veces se midió, no cuántos mensajes hay.
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  # Una cola vacía y sin tráfico no publica datos. "notBreaching" los trata como "todo bien";
  treat_missing_data = "notBreaching"
  alarm_actions = [var.alerts_topic_arn]
}

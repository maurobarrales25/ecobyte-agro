#  Alarma que vigila la salud del pipeline: un mensaje en la DLQ es una lectura que falló
# `maxReceiveCount` veces y no se pudo guardar.
resource "aws_cloudwatch_metric_alarm" "dlq_has_messages" {
  alarm_name        = "${var.name_prefix}-dlq-con-mensajes"
  alarm_description = "Hay lecturas que fallaron y no se guardaron"
  namespace         = "AWS/SQS"
  metric_name       = "ApproximateNumberOfMessagesVisible"
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
  alarm_actions      = [var.alerts_topic_arn]
}

# Cada widget del dashboard necesita la región; se lee del provider en vez de escribirla a mano.
data "aws_region" "current" {}

# Dashboard del pipeline. La grilla tiene 24 columnas: con width = 12 entran dos widgets por
# fila (x = 0 y x = 12). Cada fila empieza donde termina la anterior: y = 0, 6 y 12 (height = 6).
# Cada métrica es [namespace, nombre, nombre de la dimensión, valor de la dimensión].
resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title   = "Cola de ingesta: mensajes esperando"
          region  = data.aws_region.current.region
          period  = 60
          stat    = "Maximum"
          metrics = [["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.ingest_queue_name]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title   = "DLQ: lecturas que fallaron"
          region  = data.aws_region.current.region
          period  = 60
          stat    = "Maximum"
          metrics = [["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.dlq_queue_name]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title   = "Lambda: invocaciones"
          region  = data.aws_region.current.region
          period  = 60
          stat    = "Sum"
          metrics = [["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name]]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title   = "Lambda: errores"
          region  = data.aws_region.current.region
          period  = 60
          stat    = "Sum"
          metrics = [["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name]]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        # Tres estadísticas de la misma métrica en un gráfico: el último elemento de cada fila
        # es un objeto con opciones que pisan el stat del widget. Si el p95 o el máximo suben con
        # la carga, el consumidor (o DynamoDB y SNS) es el cuello de botella. Duration está en ms.
        properties = {
          title  = "Lambda: duración (ms)"
          region = data.aws_region.current.region
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "Average", label = "promedio" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "p95", label = "p95" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "Maximum", label = "máximo" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        # Cuántas copias de la Lambda corren a la vez. Con la cola llena debería llegar a
        # max_concurrency (variable del módulo consumer): ahí el tope lo pone esa variable.
        properties = {
          title   = "Lambda: ejecuciones concurrentes"
          region  = data.aws_region.current.region
          period  = 60
          stat    = "Maximum"
          metrics = [["AWS/Lambda", "ConcurrentExecutions", "FunctionName", var.lambda_function_name]]
        }
      }
    ]
  })
}

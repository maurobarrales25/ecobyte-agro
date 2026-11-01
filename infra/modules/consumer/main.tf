locals {
  function_name = "${var.name_prefix}-consumidor"
}

# Zip del código. Se arma en cada plan; si el código cambia, cambia el hash y se actualiza la Lambda.
data "archive_file" "code" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${local.function_name}.zip"
  excludes    = ["__pycache__", "**/__pycache__/**", "**/*.pyc"]
}

# Se crea antes que la Lambda para controlar la retención. Si la creara la Lambda sola,
# quedaría sin vencimiento y fuera del estado (el destroy no la borraría).
#trivy:ignore:AWS-0017 Sin clave KMS propia: tiene costo y los logs no llevan datos sensibles.
resource "aws_cloudwatch_log_group" "consumer" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------
# Rol de la Lambda: solo lo que necesita, cada acción acotada a su recurso.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "consumer" {
  name               = local.function_name
  description        = "Lambda consumidora: lee la cola de ingesta, guarda en DynamoDB y alerta por SNS"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "consumer" {
  # Lo que usa el event source mapping para leer y borrar mensajes en nombre de la Lambda.
  statement {
    sid       = "ReadIngestQueue"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [var.queue_arn]
  }

  # Solo escribir: la Lambda no lee ni borra lecturas.
  statement {
    sid       = "WriteReadings"
    actions   = ["dynamodb:PutItem"]
    resources = [var.table_arn]
  }

  statement {
    sid       = "PublishAlerts"
    actions   = ["sns:Publish"]
    resources = [var.alerts_topic_arn]
  }

  # Sin logs:CreateLogGroup: el grupo lo crea OpenTofu arriba.
  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.consumer.arn}:*"]
  }
}

resource "aws_iam_role_policy" "consumer" {
  name   = "consumidor-menor-privilegio"
  role   = aws_iam_role.consumer.id
  policy = data.aws_iam_policy_document.consumer.json
}

# ---------------------------------------------------------------------------
# Función y vínculo con la cola
# ---------------------------------------------------------------------------
#trivy:ignore:AWS-0066 Sin X-Ray: los logs y las métricas de CloudWatch alcanzan para este flujo.
resource "aws_lambda_function" "consumer" {
  function_name    = local.function_name
  role             = aws_iam_role.consumer.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.memory_mb

  environment {
    variables = {
      TABLE_NAME      = var.table_name
      TTL_ATTRIBUTE   = var.ttl_attribute_name
      TOPIC_ARN       = var.alerts_topic_arn
      ALERT_THRESHOLD = tostring(var.alert_threshold_celsius)
    }
  }

  depends_on = [aws_cloudwatch_log_group.consumer]
}

# La cola dispara la Lambda con lotes de batch_size mensajes.
resource "aws_lambda_event_source_mapping" "ingest" {
  event_source_arn = var.queue_arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = var.batch_size

  # La Lambda devuelve qué mensajes fallaron; SQS reintenta solo esos y no el lote entero.
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = var.max_concurrency
  }

  # AWS valida al crear el vínculo que el rol ya pueda leer la cola.
  depends_on = [aws_iam_role_policy.consumer]
}

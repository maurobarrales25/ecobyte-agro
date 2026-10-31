# Lecturas de los sensores. Un ítem por sensor y por instante de lectura, si SQS
# entrega un mensaje dos veces (entrega "al menos una vez"), la segunda escritura pisa al mismo
# ítem y no queda un duplicado.
resource "aws_dynamodb_table" "readings" {
  name         = "${var.name_prefix}-lecturas"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "sensor_id"
  range_key    = "timestamp"

  attribute {
    name = "sensor_id"
    type = "S"
  }

  # Milisegundos desde 1970, tomados de la lectura y no de la hora de proceso.
  attribute {
    name = "timestamp"
    type = "N"
  }

  # Borrado automático: los datos de prueba no se acumulan.
  ttl {
    attribute_name = var.ttl_attribute_name
    enabled        = true
  }

  # El entorno se destruye al final de cada sesión; con la protección activa el destroy fallaría.
  deletion_protection_enabled = false

  # Sin recuperación a un punto en el tiempo (point_in_time_recovery) a propósito: tiene costo por
  # GB y son datos de prueba que vencen solos a los 30 días. Tampoco hay clave KMS propia: la
  # tabla se cifra con una clave de AWS.
}

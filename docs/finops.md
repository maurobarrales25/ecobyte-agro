# FinOps

## Budget

Se setea un budget de 5 dólares mensuales para todo el proyecto. Es más estricto que los 10 dólares que sugiere la consigna, porque la arquitectura es serverless y el costo esperado es muy bajo (la consigna estima entre 0 y 1 dólar al mes para este proyecto).

El presupuesto se llama `ecobyte-monthly` y se crea con OpenTofu en `infra/bootstrap/`. El límite es la variable `budget_limit_usd`. Si hace falta subirlo para hacer las pruebas y cumplir con el lab, se cambia ahí y pasa por un PR, así queda registrado.

Vive en el bootstrap, separado del entorno y con su propio estado (`bootstrap/terraform.tfstate`).

## Alertas

Se configuran alertas por email al 50%, 80% y 100% del gasto real (2,50, 4 y 5 dólares). Además hay una alerta de gasto previsto al 100%, que avisa cuando AWS proyecta que nos vamos a pasar, antes de que pase.

Las alertas llegan a nuestros mails. Los correos no están en el repo, se guardan en AWS Systems Manager Parameter Store, en el parámetro `/ecobyte/budget-emails` (tipo `SecureString`, con la lista de correos en JSON). Se crea a mano una sola vez, y el bootstrap lo lee con un `data "aws_ssm_parameter"`. Así cada integrante solo necesita su usuario IAM, sin compartir ni exportar ningún valor.

Los emails de un presupuesto no necesitan confirmación, a diferencia de las suscripciones de SNS. Para cambiar un destinatario se actualiza el parámetro y se vuelve a aplicar el bootstrap.

Las alertas sólo envían un mensaje, no llevan a cabo ninguna acción. Esto se puede ver en `infra/bootstrap/main.tf`, donde el presupuesto tiene solo bloques `notification` y ninguna budget action.

## Por qué no hay budget actions

Las budget actions pueden adjuntar una política IAM de denegación o parar instancias EC2 y RDS. No las usamos por estas razones:

- El stack es serverless (SQS, Lambda, DynamoDB), no hay nada que "parar".
- Necesitan un rol que pueda modificar IAM, lo que va contra el menor privilegio.
- Podrían dejar bloqueada a la Lambda o al simulador justo en la prueba de carga o en la demo.

## Estimación de costo

SQS, Lambda, DynamoDB y SNS son de pago por uso y escalan a cero. CloudWatch cobra por uso (logs y métricas), pero además tiene un costo mensual por cada alarma, por dashboard (a partir del cuarto) y por métrica personalizada, aunque no haya tráfico:

| Servicio | Qué se cobra |
| --- | --- |
| SQS (ingesta y DLQ) | Por cantidad de solicitudes |
| Lambda | Por invocaciones y por tiempo de ejecución |
| DynamoDB | Por lecturas, escrituras y almacenamiento |
| SNS | Por notificaciones enviadas |
| CloudWatch | Por logs, métricas personalizadas, dashboards y alarmas |

Supuestos a definir para la cuenta: cantidad de mensajes de la prueba (10.000), duración de la Lambda y memoria configurada.

## Costo real

## Proyección a escala

## Medidas de ahorro

- Presupuesto con alertas creado desde el primer día.
- Los recursos creados con OpenTofu llevan las etiquetas `project`, `team`, `env` y `owner`, definidas en `default_tags` del provider. Hoy el único recurso es el presupuesto. El bucket del estado y el parámetro de SSM, que se crearon a mano, se etiquetaron con los mismos valores.
    Con un solo entorno y un solo equipo no separan el gasto, pero permiten acotar permisos por
    etiqueta y encontrar recursos que hayan quedado vivos.
- TTL en la tabla de lecturas `ecobyte-dev-lecturas`: la tabla borra sola los ítems que ya vencieron, usando el atributo `expires_at`. La Lambda va a escribir ese atributo con la fecha de la lectura más 30 días, así que cada ítem dura 30 días desde que se guarda. Esto se hace porque DynamoDB cobra el almacenamiento por GB al mes, y así los datos de prueba no se acumulan. El borrado por TTL no tiene costo, pero no es inmediato: AWS lo hace en segundo plano y puede tardar hasta unas 48 horas, o más, después del vencimiento. Para esto no importa, porque solo buscamos limpiar datos de prueba.
- Sin recuperación a un punto en el tiempo (point-in-time recovery) ni clave KMS propia en la tabla: tienen costo por GB y son datos de prueba que vencen solos.

## Evidencia del destroy

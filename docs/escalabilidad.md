# Escalabilidad

Qué pasa con el sistema si la cantidad de sensores crece 10 y 100 veces, dónde se traba primero y qué servicio crece más rápido en costo.

> Borrador con datos de la documentación oficial de AWS (consultada el 3 de noviembre de 2026). Los tiempos de procesamiento son supuestos hasta que se haga la prueba de carga de 10.000 mensajes con la lógica real de la Lambda. Los costos se confirman con la [calculadora de AWS](https://calculator.aws).

## Recorrido de un mensaje

```
simulador -> SQS ingesta -> Lambda (lotes de 10, concurrencia máxima 5) -> DynamoDB
                                     └─ temperatura > 35 °C -> SNS -> email
```

Cada servicio escala por su cuenta. La cola desacopla a quien produce (los sensores) de quien consume (la Lambda): si llegan más mensajes de los que la Lambda puede procesar, se acumulan en la cola y se procesan después, sin perderse.

## Supuestos

| Supuesto | Valor | De dónde sale |
|---|---|---|
| Frecuencia de cada sensor | 1 lectura por minuto | Supuesto del equipo |
| Lecturas sobre 35 °C | 1 % | Valor por defecto del simulador (`--hot-ratio 0.01`) |
| Suscriptores del tópico de alertas | 2 | Los dos integrantes |
| Tiempo por lote de 10 mensajes | 100 ms | Supuesto; se mide en la prueba de carga |
| Memoria de la Lambda | 128 MB | `memory_mb` del módulo `consumer` |
| Tamaño de cada ítem en DynamoDB | ~200 bytes | Cuatro atributos chicos más la sobrecarga del ítem |
| Retención de lecturas | 30 días | TTL de la tabla |
| Pedidos a SQS por mensaje | 0,3 | Envío, recepción y borrado en lotes de 10 |
| Logs por invocación | ~500 bytes | Líneas `START`, `END` y `REPORT` |
| Región | `us-east-1` | Región del proyecto |

Los costos están **sin capa gratuita**, para que se pueda comparar entre escenarios.

## Escenarios

| | Base | 10x | 100x |
|---|---|---|---|
| Sensores | 1.000 | 10.000 | 100.000 |
| Mensajes por segundo (promedio) | 17 | 167 | 1.667 |
| Mensajes por mes | 43 M | 432 M | 4.320 M |
| Lambdas en paralelo necesarias | 0,2 | 1,7 | 16,7 |
| Emails de alerta por segundo (por suscripción) | 0,2 | 1,7 | 16,7 |
| Datos guardados en DynamoDB | 9 GB | 86 GB | 864 GB |

Las Lambdas en paralelo salen de: mensajes por segundo ÷ 10 (lote) × 0,1 s (tiempo por lote).

## Costo mensual estimado (USD)

| Servicio | Base | 10x | 100x |
|---|---|---|---|
| SQS | 5 | 52 | 518 |
| Lambda | 2 | 18 | 176 |
| DynamoDB, escrituras | 27 | 270 | 2.700 |
| DynamoDB, almacenamiento | 2 | 22 | 216 |
| SNS, emails | 17 | 173 | 1.728 |
| CloudWatch Logs | 1 | 11 | 108 |
| **Total** | **~54** | **~545** | **~5.450** |

El costo crece lineal con los sensores: 10 veces más sensores, 10 veces más costo. Es lo esperable en serverless, donde se paga por uso y no por capacidad reservada.

Precios usados (`us-east-1`, lista de precios pública de AWS):

| Servicio | Precio |
|---|---|
| SQS estándar | USD 0,40 por millón de pedidos |
| Lambda | USD 0,20 por millón de invocaciones y USD 0,0000166667 por GB-segundo |
| DynamoDB on-demand | USD 0,625 por millón de escrituras y USD 0,25 por GB al mes |
| SNS email | USD 2 cada 100.000 notificaciones |
| CloudWatch Logs | USD 0,50 por GB ingerido |

## Cuello de botella de rendimiento: la concurrencia de la Lambda

Con `max_concurrency = 5` y 100 ms por lote, el consumidor procesa como máximo:

```
5 Lambdas × 10 mensajes por lote ÷ 0,1 s = 500 mensajes por segundo
```

| Escenario | Llegan | Se procesan | Resultado |
|---|---|---|---|
| Base | 17/s | hasta 500/s | Sobra capacidad |
| 10x | 167/s | hasta 500/s | Sobra capacidad |
| 100x | 1.667/s | 500/s | La cola crece sin parar |

En 100x es lo primero que se traba. Las opciones:

1. **Subir `max_concurrency`.** Es una variable del módulo `consumer` y acepta de 2 a 1.000. Para 100x alcanza con unas 20.
2. **Revisar el límite de la cuenta.** AWS permite por defecto 1.000 Lambdas en paralelo por región, pero las cuentas nuevas tienen límites reducidos que suben solos con el uso. Se consulta con `aws lambda get-account-settings --query AccountLimit`.
3. **Techo del vínculo con SQS.** Lambda empieza con 5 invocaciones en paralelo y suma hasta 300 por minuto, con un máximo de 1.250 para colas estándar. Más allá hay que activar el modo aprovisionado (hasta 100.000).

## El límite también protege a la base de datos

Los sensores pueden mandar todos a la vez (por ejemplo, en el segundo :00 de cada minuto). En 100x serían 100.000 mensajes de golpe.

- SQS los absorbe: las colas estándar aceptan llamadas "casi ilimitadas" por segundo y no tienen tope de mensajes en espera.
- Una tabla on-demand nueva aguanta 4.000 escrituras por segundo de entrada y puede duplicar su pico anterior. Si se pasa del doble en menos de 30 minutos, puede rechazar escrituras (throttling).
- Con `max_concurrency` acotado, la Lambda saca mensajes de la cola a un ritmo que DynamoDB puede aguantar. Sin ese límite, la Lambda podría escalar más rápido que la tabla.

Este es el desacople que buscamos con la cola: el pico se transforma en una cola que se vacía a ritmo constante.

## Lo que más crece en costo: escrituras en DynamoDB

DynamoDB es cerca del 50 % del costo en todos los escenarios. Lambda y SQS trabajan en lotes de 10, pero DynamoDB cobra cada escritura por separado: una lectura de sensor es una escritura.

Formas de bajarlo:

- **Agregar antes de guardar.** Guardar un promedio por sensor por minuto o por hora en vez de cada lectura. Es el extra opcional de "agregación por hora".
- **Bajar la frecuencia de los sensores.** Una lectura cada 5 minutos en vez de cada minuto divide el costo por 5.
- **Capacidad aprovisionada.** Con carga estable y predecible puede salir más barata que on-demand. Habría que compararlo en la calculadora.

## Problema de diseño: una alerta por lectura no escala

Hoy cada lectura sobre 35 °C manda un email.

- En 100x serían 86 millones de emails por mes (USD 1.728) y 16,7 por segundo por suscripción.
- SNS tiene un límite fijo de 10 emails por segundo por suscripción, que no se puede aumentar. Los emails se atrasarían.
- Además, nadie puede leer esa cantidad de alertas.

La solución es deduplicar: por ejemplo, una alerta por sensor cada 15 minutos, o un resumen periódico con los sensores que pasaron el umbral. Para el alcance del proyecto (demo con pocos sensores) no hace falta, pero es el primer cambio si el sistema creciera.

## SQS no es el límite

- Las colas estándar no tienen un tope fijo de mensajes por segundo.
- No hay límite de mensajes esperando en la cola.
- Solo hay un tope de ~120.000 mensajes "en proceso" (recibidos y no borrados) al mismo tiempo, muy por encima de lo que usa el consumidor (5 Lambdas × 10 mensajes = 50).
- Si los mensajes se acumulan, la retención es de 4 días, ampliable a 14.

## Resumen

| Pregunta | Respuesta |
|---|---|
| ¿Qué se traba primero? | La concurrencia de la Lambda (500 msg/s con `max_concurrency = 5`). Aparece en 100x. |
| ¿Cómo se arregla? | Subir `max_concurrency` y, si hace falta, pedir más concurrencia para la cuenta. |
| ¿Qué crece más en costo? | Las escrituras en DynamoDB (~50 % del total). |
| ¿Qué no escala por diseño? | Una alerta por email por lectura. |
| ¿Qué escala sin cambios? | SQS y el almacenamiento de DynamoDB (el TTL limita lo guardado a 30 días). |

## Pendiente

- [ ] Medir el tiempo real por lote en la prueba de 10.000 mensajes y recalcular la capacidad.
- [ ] Consultar el límite de concurrencia de Lambda de la cuenta.
- [ ] Cargar los tres escenarios en la calculadora de AWS y adjuntar el link.
- [ ] Agregar el gráfico de profundidad de cola de la prueba de carga.

## Fuentes

- [Escalado de Lambda con SQS](https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-scaling.html)
- [Límites de Lambda](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
- [Límites de mensajes de SQS](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-messages.html)
- [Límites de colas de SQS](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/quotas-queues.html)
- [DynamoDB on-demand](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/on-demand-capacity-mode.html)
- [Límites de SNS](https://docs.aws.amazon.com/general/latest/gr/sns.html)
- Precios: [SQS](https://aws.amazon.com/sqs/pricing/), [Lambda](https://aws.amazon.com/lambda/pricing/), [DynamoDB](https://aws.amazon.com/dynamodb/pricing/on-demand/), [SNS](https://aws.amazon.com/sns/pricing/), [CloudWatch](https://aws.amazon.com/cloudwatch/pricing/)

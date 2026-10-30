# Elección de Provider - AWS

La elección de AWS se debe a que la gran mayoría de los labs se desarrollaron en AWS, además es el provider con mas usuarios en el mercado, por lo cual decidimos elegirlo sobre Azure y Google Cloud.

## Decisión

- Provider: AWS.
- Región: `us-east-1`, una sola región para todo el proyecto.
- Herramienta de infraestructura como código: OpenTofu.

## Servicios que usa el proyecto

EcoByte Agro es una arquitectura serverless de mensajería. Cada componente tiene su servicio en AWS y su equivalente en los otros dos proveedores:

| Componente | AWS | Google Cloud | Azure |
| --- | --- | --- | --- |
| Cola de ingesta y DLQ | SQS | Pub/Sub | Service Bus / Storage Queues |
| Función consumidora | Lambda | Cloud Run functions | Azure Functions |
| Base NoSQL con TTL | DynamoDB | Firestore | Cosmos DB / Table Storage |
| Tópico de notificaciones (alerta por email) | SNS (suscripción por email) | Pub/Sub (el correo requiere un servicio extra) | Service Bus (el correo requiere un servicio extra) |
| Dashboard y alarmas | CloudWatch | Cloud Monitoring / Logging | Azure Monitor / Log Analytics |
| Permisos | IAM | IAM (service accounts) | Entra ID + RBAC |
| Valores guardados | SSM Parameter Store | Secret Manager | Key Vault |
| Presupuestos | AWS Budgets | Cloud Billing Budgets | Cost Management Budgets |

## Costo

SQS, Lambda, DynamoDB y SNS son de pago por uso y escalan a cero. CloudWatch suma un costo mensual por alarma y por dashboard (a partir del cuarto), aunque no haya tráfico. Ningún servicio elegido cobra por hora encendido. La consigna estima para este proyecto entre 0 y 1 dólar al mes. El detalle y el control de gasto están en `docs/finops.md`.

La cuenta usa el plan gratuito de AWS. Por eso no se usan Organizations ni IAM Identity Center, que convertirían la cuenta a plan pago y harían vencer los créditos.

## Experiencia del equipo

Los labs de la materia se hicieron en AWS, así ya conocemos por arriba algunos de los servicios que vamos a utilizar gracias a dichos labs.

## Por qué no Azure ni Google Cloud

- Para este caso no hay una ventaja técnica clara en ninguno de los dos, los artefactos tienen equivalentes en cada provider.
- Cambiar de provider implicaría aprender de nuevo herramientas, permisos, servicios, etc.  en un proyecto corto y a entregar en semanas.

## Región

Se usa una sola región, `us-east-1`, como pide la consigna, y no hay requisitos de alta disponibilidad entre regiones.

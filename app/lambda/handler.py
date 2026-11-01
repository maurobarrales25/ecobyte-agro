def handler(event, context):
    # Relleno para poder empaquetar y desplegar la infra.
    # La lógica real (DynamoDB, SNS, expires_at) va en la rama app/lambda.
    return {"batchItemFailures": []}

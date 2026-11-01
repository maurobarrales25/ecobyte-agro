# Simulador de sensores

Script local que publica lecturas de temperatura en la cola de ingesta (SQS), a un ritmo fijo de mensajes por segundo. Reemplaza al hardware de campo.

## Formato del mensaje

Un JSON por mensaje, que es el contrato con la Lambda consumidora:

```json
{"sensor_id": "sensor-0007", "timestamp": 1793540000000, "temperature": 24.3}
```

- `sensor_id`: `sensor-0001` a `sensor-NNNN` (según `--sensors`).
- `timestamp`: milisegundos desde 1970. Un mismo sensor nunca repite el valor, porque `sensor_id` + `timestamp` es la clave de la tabla y una repetición pisaría la lectura anterior.
- `temperature`: grados Celsius con un decimal. Normal entre 12 y 32; con probabilidad `--hot-ratio`, entre 35,1 y 42 (dispara la alerta).

## Uso

```bash
python3 -m venv .venv
.venv/bin/pip install -r app/simulator/requirements.txt
```

La URL de la cola sale del estado de OpenTofu, no del código:

```bash
export QUEUE_URL=$(tofu -chdir=infra/envs/dev output -raw ingest_queue_url)
```

```bash
# Prueba corta: 20 mensajes a 5 por segundo, uno de cada cuatro sobre 35 °C
.venv/bin/python app/simulator/simulator.py --count 20 --rate 5 --hot-ratio 0.25

# Prueba de carga: 10.000 mensajes a 100 por segundo (unos 100 s)
.venv/bin/python app/simulator/simulator.py --count 10000 --rate 100

# Sin AWS: imprime los mensajes en pantalla
.venv/bin/python app/simulator/simulator.py --dry-run --count 10
```

| Opción | Por defecto | Qué hace |
|---|---|---|
| `--queue-url` | `$QUEUE_URL` | Cola de ingesta |
| `--count` | 100 | Total de mensajes |
| `--rate` | 10 | Mensajes por segundo |
| `--sensors` | 50 | Sensores distintos |
| `--hot-ratio` | 0.01 | Proporción de lecturas sobre 35 °C |
| `--profile` | sesión actual | Perfil de AWS (para usar la identidad del simulador) |
| `--dry-run` | no | Imprime en vez de enviar |

Los mensajes se envían en lotes de 10 (`SendMessageBatch`), el máximo de SQS: 10.000 mensajes son 1.000 llamadas. El progreso se imprime una vez por segundo y sale con código 1 si algún mensaje falló.

## Credenciales

Usa la sesión de `aws login` o el perfil que se pase con `--profile`. El simulador solo necesita `sqs:SendMessage` sobre la cola de ingesta; `SendMessageBatch` usa ese mismo permiso. Nunca se crean access keys.

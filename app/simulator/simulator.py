"""Simulador de sensores de temperatura de EcoByte Agro.

Publica lecturas en la cola de ingesta (SQS) a un ritmo fijo de mensajes por segundo.
Cada mensaje es un JSON con el formato que espera la Lambda consumidora:

    {"sensor_id": "sensor-0007", "timestamp": 1793540000000, "temperature": 24.3}

La URL de la cola no va en el código: se pasa con --queue-url o con la variable QUEUE_URL
(sale de `tofu output -raw ingest_queue_url`).
"""

import argparse
import json
import os
import random
import sys
import time

import boto3

# SQS acepta hasta 10 mensajes por llamada; enviar en lotes reduce llamadas y costo.
SQS_BATCH_MAX = 10
ALERT_THRESHOLD = 35.0


def parse_args():
    parser = argparse.ArgumentParser(description="Simulador de sensores de temperatura")
    parser.add_argument("--queue-url", default=os.environ.get("QUEUE_URL"),
                        help="URL de la cola de ingesta (o variable QUEUE_URL)")
    parser.add_argument("--count", type=int, default=100, help="Total de mensajes a enviar")
    parser.add_argument("--rate", type=int, default=10, help="Mensajes por segundo")
    parser.add_argument("--sensors", type=int, default=50, help="Cantidad de sensores distintos")
    parser.add_argument("--hot-ratio", type=float, default=0.01,
                        help="Proporción de lecturas por encima de 35 °C (0 a 1)")
    parser.add_argument("--profile", help="Perfil de AWS a usar (por defecto, el de la sesión)")
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument("--dry-run", action="store_true",
                        help="Imprime los mensajes en vez de enviarlos")
    args = parser.parse_args()

    if not args.dry_run and not args.queue_url:
        parser.error("falta --queue-url o la variable QUEUE_URL")
    if args.count < 1 or args.rate < 1 or args.sensors < 1:
        parser.error("--count, --rate y --sensors deben ser mayores que 0")
    if not 0 <= args.hot_ratio <= 1:
        parser.error("--hot-ratio debe estar entre 0 y 1")
    return args


def make_reading(sensors, hot_ratio, last_ts):
    """Una lectura: temperatura normal de campo o, con probabilidad hot_ratio, una de alerta."""
    if random.random() < hot_ratio:
        temperature = random.uniform(ALERT_THRESHOLD + 0.1, 42.0)
    else:
        temperature = random.uniform(12.0, 32.0)

    sensor_id = f"sensor-{random.randint(1, sensors):04d}"
    # La tabla usa sensor_id + timestamp como clave: si un sensor repitiera el milisegundo,
    # la segunda lectura pisaría a la primera. Se corre 1 ms para que no se pierdan datos.
    timestamp = max(time.time_ns() // 1_000_000, last_ts.get(sensor_id, 0) + 1)
    last_ts[sensor_id] = timestamp

    return {"sensor_id": sensor_id, "timestamp": timestamp, "temperature": round(temperature, 1)}


def send_batch(sqs, queue_url, readings):
    """Envía hasta 10 lecturas en una llamada. Devuelve cuántas fallaron."""
    entries = [{"Id": str(i), "MessageBody": json.dumps(r)} for i, r in enumerate(readings)]
    response = sqs.send_message_batch(QueueUrl=queue_url, Entries=entries)
    for failed in response.get("Failed", []):
        print(f"  falló el mensaje {failed['Id']}: {failed.get('Code')} {failed.get('Message')}",
              file=sys.stderr)
    return len(response.get("Failed", []))


def main():
    args = parse_args()
    sqs = None
    if not args.dry_run:
        session = boto3.Session(profile_name=args.profile, region_name=args.region)
        sqs = session.client("sqs")

    sent = failed = hot = 0
    last_ts = {}
    start = time.monotonic()

    # Cada vuelta envía los mensajes de un segundo y espera lo que falte para completarlo.
    while sent + failed < args.count:
        second_start = time.monotonic()
        to_send = min(args.rate, args.count - sent - failed)
        readings = [make_reading(args.sensors, args.hot_ratio, last_ts) for _ in range(to_send)]
        hot += sum(r["temperature"] > ALERT_THRESHOLD for r in readings)

        for i in range(0, len(readings), SQS_BATCH_MAX):
            batch = readings[i:i + SQS_BATCH_MAX]
            if args.dry_run:
                for r in batch:
                    print(json.dumps(r))
                errors = 0
            else:
                errors = send_batch(sqs, args.queue_url, batch)
            sent += len(batch) - errors
            failed += errors

        elapsed = time.monotonic() - start
        print(f"[{elapsed:6.1f}s] enviados {sent}/{args.count}  fallidos {failed}  "
              f"sobre 35 °C {hot}", file=sys.stderr)

        remaining = 1.0 - (time.monotonic() - second_start)
        if remaining > 0 and sent + failed < args.count:
            time.sleep(remaining)

    elapsed = time.monotonic() - start
    print(f"Listo: {sent} enviados, {failed} fallidos, {hot} sobre 35 °C, "
          f"{elapsed:.1f} s ({sent / elapsed:.0f} msg/s)", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

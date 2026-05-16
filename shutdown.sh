#!/usr/bin/env bash
# shutdown.sh — Para todos los servicios del curso sin borrar datos.

cd "$(dirname "$0")"
echo ""
echo "Parando el laboratorio..."
cd docker
docker compose stop
echo ""
echo "Listo. Los datos siguen ahí. Para volver a arrancar, ejecuta ./setup.sh."

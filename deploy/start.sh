#!/bin/bash
# Startskript för API:t. Supervisor kör det som användaren fastapi_service.
# exec = uvicorn ersätter bash-processen, så att Supervisor kan stoppa den korrekt.
set -e
cd /home/fastapi_service/fastapi_app/api
# shellcheck source=/dev/null
source venv/bin/activate
# 127.0.0.1 = API:t går bara att nå inifrån servern. Utifrån går trafiken via Nginx (port 80).
exec uvicorn main:app --host 127.0.0.1 --port 8000 --workers 1 --proxy-headers

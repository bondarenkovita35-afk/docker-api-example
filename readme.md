# DevOps-examination – utvecklingsmiljö för ett FastAPI-API (G)

Fork av [UA-classroom/docker-api-example](https://github.com/UA-classroom/docker-api-example).
API:t (filmer, användare, recensioner) driftsätts på en ny Ubuntu 24.04-server i AWS EC2 med
PostgreSQL, Supervisor och Nginx. Servern sätts upp med ett Bash-skript, och CRON kör backup
och övervakning med larm till Discord.

## Arkitektur

```
 Student A (Windows)      Student B (Windows)           Webbläsare
   ssh -i devops-key.pem    ssh -i devops_studentb       http://<Elastic-IP>/docs
        │ 22                     │ 22                           │ 80
        └───────────┬────────────┘                              │
                    ▼                                           ▼
 ┌──── AWS Security Group: in 22 (våra två IP), in 80 (alla) ───────────────┐
 │  EC2 t3.micro, Ubuntu 24.04 LTS, Elastic IP                              │
 │  UFW: 22, 80   ·   fail2ban (SSH)                                        │
 │                                                                          │
 │  Nginx :80 ──► Uvicorn 127.0.0.1:8000 ──► FastAPI (api/main.py)          │
 │               Supervisor "fastapi_app"          │                        │
 │               användare fastapi_service         ▼                        │
 │                                   PostgreSQL 127.0.0.1:5432              │
 │                                   fastapi_movies_db / fastapi_user       │
 │                                                                          │
 │  root-crontab: 02:00  backup.sh         → /var/backups/fastapi_app       │
 │                */5    monitor_system.sh → Discord-webhook                │
 └──────────────────────────────────────────────────────────────────────────┘
```

Port 8000 och 5432 är **inte** öppna mot internet.

## G-krav och lösning

| # | Krav | Lösning |
|---|------|---------|
| 1 | EC2 free tier, Security Groups, Elastic IP, från scratch | t3.micro, SG 22/80, Elastic IP ([docs/GUIDE_RU.md](docs/GUIDE_RU.md) steg 1–2) |
| 2 | SSH-nycklar för båda datorerna | AWS-nyckel för `ubuntu` + eget konto `studentb` med egen nyckel ([deploy/scripts/add_user.sh](deploy/scripts/add_user.sh)) |
| 3 | Bash-skript: alias, paket, extra användare, SCP + körning | [deploy/scripts/setup.sh](deploy/scripts/setup.sh) |
| 4 | Klona repot till en användares hemkatalog | `/home/fastapi_service/fastapi_app` |
| 5 | Backup med CRON (databas + loggar) | [deploy/scripts/backup.sh](deploy/scripts/backup.sh), kopia till egen dator med `scp` |
| 6 | Schemalagd monitoring → Discord | [deploy/scripts/monitor_system.sh](deploy/scripts/monitor_system.sh): disk, CPU, RAM, API, Supervisor, misslyckade SSH-inloggningar |
| 7 | Process manager, `http://<ip>/docs` | Supervisor: [deploy/config/fastapi_app.conf](deploy/config/fastapi_app.conf), [deploy/start.sh](deploy/start.sh) |
| 8 | Reverse proxy | Nginx: [deploy/config/nginx_fastapi_app](deploy/config/nginx_fastapi_app) |
| 9 | PostgreSQL | lokalt på EC2, egen användare `fastapi_user` |

## Struktur

```
api/                      lärarens API (FastAPI + psycopg2)
  main.py db.py schemas.py exceptions.py
  setup.py                skapar tabeller + testdata (DB_USER kan nu sättas i .env)
  requirements.txt        låsta versioner
deploy/
  start.sh                startar Uvicorn (körs av Supervisor)
  config/fastapi_app.conf Supervisor
  config/nginx_fastapi_app Nginx
  config/crontab.txt      rader för sudo crontab -e
  config/monitor.env.example
  scripts/setup.sh        grundinstallation (scp + sudo bash)
  scripts/add_user.sh     konto + SSH-nyckel för student B
  scripts/backup.sh       pg_dump + loggar
  scripts/monitor_system.sh  övervakning + Discord
  scripts/smoke_test.sh   testar alla endpoints
docs/GUIDE_RU.md          steg för steg (ryska), alla kommandon förklarade
docs/REPETITION_RU.md     plan för repetition
CHECKLIST.md  VIDEO_SCRIPT.md  TROUBLESHOOTING.md
.env.example              exempel, inga riktiga hemligheter
```

## Skillnader mot lärarens repetitionsguide

| Guiden | Här | Varför |
|--------|-----|--------|
| t2.micro | t3.micro | t2 finns inte i eu-north-1 |
| port 8000 öppen | stängd, Uvicorn på 127.0.0.1 | all trafik via Nginx, färre öppna portar |
| `/var/www/fastapi_app` | `/home/fastapi_service/fastapi_app` | G-kravet: användarens hemkatalog |
| DB-användare `postgres` | `fastapi_user` | API:t ska inte vara databasadmin |
| `start.sh` kör `setup.py` vid varje start | `setup.py` körs en gång | annars dupliceras testrecensioner |
| `--workers 2` | `--workers 1` | testat: med 2 workers kunde Supervisor inte starta om efter krasch (port upptagen); 1 GB RAM |
| monitor skriver bara logg | logg + Discord + SSH-kontroll | G-krav 6 |
| ingen backup | backup.sh + CRON + scp | G-krav 5 |

## Testat lokalt (Ubuntu WSL)

- `bash -n` och ShellCheck: alla skript utan anmärkningar.
- API mot PostgreSQL 18 med `fastapi_user`, `setup.py`, Supervisor (krasch → automatisk omstart), Nginx-konfiguration (`nginx -t`) och `smoke_test.sh` via Nginx: 10 PASS.
- `monitor_system.sh` mot en lokal test-webhook: testmeddelande, SSH-larm, API-nere, återställt.
- `pg_dump` + `pg_restore` av databasen.
- Inte testat lokalt: `setup.sh` och `backup.sh` i sin helhet (kräver root, apt och systemd på en riktig server). Testas vid repetitionen på EC2.

## Säkerhet

- Inga hemligheter i Git (`.gitignore`): `.env` och `monitor.env` skapas bara på servern, rättigheter 600.
- SSH bara med nycklar, ingen root-inloggning, fail2ban, UFW (22, 80).
- API:t körs som `fastapi_service` utan sudo. Skript som root kör via CRON ligger i `/usr/local/bin` och ägs av root.
- HTTPS (VG): kräver en egen domän och ett certifikat från t.ex. Let's Encrypt (`certbot --nginx`).

## Efter inspelningen

Terminera instansen, släpp Elastic IP, ta bort Security Group, nyckelpar och Discord-webhook.
Kontrollera Billing.

---

Lärarens ursprungliga anteckningar (för Docker/VG):
1. Rename .env.example to .env
2. Add a dockerignore file later

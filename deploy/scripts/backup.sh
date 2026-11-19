#!/usr/bin/env bash
# =============================================================================
# backup.sh - säkerhetskopierar PostgreSQL-databasen och loggarna
#
# Installeras som /usr/local/bin/backup.sh och körs av root via CRON
# (sudo crontab -e):   0 2 * * * /usr/local/bin/backup.sh
#
# Resultat:
#   /var/backups/fastapi_app/db/fastapi_movies_db_ÅÅÅÅ-MM-DD_HHMMSS.dump  (pg_dump)
#   /var/backups/fastapi_app/logs/logs_ÅÅÅÅ-MM-DD_HHMMSS.tar.gz            (loggar)
#   Logg: /var/log/fastapi_backup.log
#   Filer äldre än RETENTION_DAYS dagar tas bort.
#
# OBS: Backuper på samma EC2 är inte optimalt. Om servern försvinner,
# försvinner backuperna också. Kopiera dem därför också till din egen dator
# med scp (se docs/GUIDE.md) eller i produktion till t.ex. Amazon S3.
#
# Återställning:
#   sudo cat <fil>.dump | sudo -u postgres pg_restore --clean --if-exists -d fastapi_movies_db
# =============================================================================
set -Eeuo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/fastapi_app}"
DB_NAME="${DB_NAME:-fastapi_movies_db}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
LOG_FILE="${LOG_FILE:-/var/log/fastapi_backup.log}"
MONITOR_ENV="/etc/fastapi_app/monitor.env"

TS="$(date +%Y-%m-%d_%H%M%S)"
DB_FILE="${BACKUP_ROOT}/db/${DB_NAME}_${TS}.dump"
LOGS_FILE="${BACKUP_ROOT}/logs/logs_${TS}.tar.gz"
STAGING=""

log() {
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S') [backup] $*"
    echo "${line}"
    echo "${line}" >> "${LOG_FILE}" 2>/dev/null || true
}

# Larma i Discord om backupen misslyckas (om webhook finns)
notify_failure() {
    local msg="$1" url=""
    if [[ -r "${MONITOR_ENV}" ]]; then
        url=$(grep -E '^DISCORD_WEBHOOK_URL=' "${MONITOR_ENV}" | cut -d= -f2- || true)
    fi
    [[ -n "${url}" ]] || return 0
    local payload
    payload=$(jq -n --arg c ":x: **BACKUP MISSLYCKADES** på $(hostname): ${msg}" '{content: $c}')
    printf 'url = "%s"\n' "${url}" | curl -fsS -m 10 -K - -H 'Content-Type: application/json' -d "${payload}" >/dev/null || true
}

cleanup() {
    if [[ -n "${STAGING}" && -d "${STAGING}" ]]; then
        rm -rf "${STAGING}"
    fi
    rm -f "${DB_FILE}.partial" "${LOGS_FILE}.partial"
}

on_error() {
    log "FEL på rad $1: $2"
    notify_failure "rad $1: $2"
    exit 1
}

trap 'on_error $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT

if [[ $EUID -ne 0 ]]; then
    echo "Kör som root: sudo $0" >&2
    exit 1
fi

umask 077   # nya filer: bara root kan läsa
mkdir -p "${BACKUP_ROOT}/db" "${BACKUP_ROOT}/logs"

log "Startar backup (${TS})"

# --- 1. Databas ---------------------------------------------------------------
# pg_dump körs som Linux-användaren postgres (peer-autentisering, inget lösenord).
# Root skriver filen. Först till .partial, byter namn när allt lyckats.
cd /tmp
runuser -u postgres -- pg_dump --format=custom "${DB_NAME}" > "${DB_FILE}.partial"
pg_restore --list "${DB_FILE}.partial" > /dev/null   # kontrollera att dumpen är giltig
mv "${DB_FILE}.partial" "${DB_FILE}"
log "Databas OK: ${DB_FILE} ($(du -h "${DB_FILE}" | cut -f1))"

# --- 2. Loggar ----------------------------------------------------------------
STAGING="$(mktemp -d)"
mkdir -p "${STAGING}/nginx" "${STAGING}/fastapi_app"
cp -a /var/log/nginx/*.log "${STAGING}/nginx/" 2>/dev/null || true
cp -a /var/log/fastapi_app/*.log "${STAGING}/fastapi_app/" 2>/dev/null || true
cp -a /var/log/system_monitor.log "${STAGING}/" 2>/dev/null || true
tar -czf "${LOGS_FILE}.partial" -C "${STAGING}" .
mv "${LOGS_FILE}.partial" "${LOGS_FILE}"
log "Loggar OK: ${LOGS_FILE} ($(du -h "${LOGS_FILE}" | cut -f1))"

# --- 3. Rensa gamla backuper --------------------------------------------------
deleted=$(find "${BACKUP_ROOT}" -type f \( -name '*.dump' -o -name '*.tar.gz' \) \
    -mtime +"${RETENTION_DAYS}" -print -delete | wc -l)
log "Rensning: ${deleted} fil(er) äldre än ${RETENTION_DAYS} dagar borttagna"
log "Backup klar. Totalt: $(du -sh "${BACKUP_ROOT}" | cut -f1)"

#!/usr/bin/env bash
# =============================================================================
# monitor_system.sh - övervakar servern och larmar till Discord
#
# Installeras som /usr/local/bin/monitor_system.sh och körs av root via CRON
# (sudo crontab -e):   */5 * * * * /usr/local/bin/monitor_system.sh
#
# Kontrollerar:
#   - diskanvändning, CPU och RAM (procent)
#   - API:t: http://localhost/status via Nginx
#   - processen fastapi_app i Supervisor, samt nginx och postgresql
#   - misslyckade SSH-inloggningar de senaste 5 minuterna (konstigt SSH-beteende)
#
# Inställningar (HEMLIGA, inte i GitHub): /etc/fastapi_app/monitor.env
#   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
#   (övriga värden har standardvärden, se nedan)
#
# Användning:
#   sudo monitor_system.sh             vanlig kontroll (som CRON gör)
#   sudo monitor_system.sh --verbose   visa alla mätvärden
#   sudo monitor_system.sh --test      skicka ett testmeddelande till Discord
#   sudo monitor_system.sh --dry-run   kontrollera men skicka inget
#
# Testa ett larm utan att belasta servern:
#   sudo DISK_THRESHOLD=0 monitor_system.sh --verbose
#
# Logg: /var/log/system_monitor.log
# Exit-kod: 0 = OK, 1 = minst ett problem, 2 = konfigurationsfel
# =============================================================================
set -Euo pipefail   # inte -e: ett misslyckat test ska inte stoppa resten

CONFIG_FILE="${CONFIG_FILE:-/etc/fastapi_app/monitor.env}"
STATE_FILE="${STATE_FILE:-/var/lib/fastapi_app_monitor.state}"
LOG_FILE="${LOG_FILE:-/var/log/system_monitor.log}"

# Värden från kommandoraden/miljön vinner över konfigurationsfilen
ENV_DISK="${DISK_THRESHOLD:-}"; ENV_CPU="${CPU_THRESHOLD:-}"; ENV_MEM="${MEM_THRESHOLD:-}"
ENV_SSH="${SSH_FAIL_THRESHOLD:-}"; ENV_API="${API_URL:-}"

DISCORD_WEBHOOK_URL=""
if [[ -r "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

DISK_THRESHOLD="${ENV_DISK:-${DISK_THRESHOLD:-80}}"
CPU_THRESHOLD="${ENV_CPU:-${CPU_THRESHOLD:-80}}"
MEM_THRESHOLD="${ENV_MEM:-${MEM_THRESHOLD:-90}}"
SSH_FAIL_THRESHOLD="${ENV_SSH:-${SSH_FAIL_THRESHOLD:-5}}"
API_URL="${ENV_API:-${API_URL:-http://localhost/status}}"
REALERT_MINUTES="${REALERT_MINUTES:-60}"

VERBOSE=0; DRY_RUN=0; TEST=0
for arg in "$@"; do
    case "${arg}" in
        --verbose) VERBOSE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --test)    TEST=1 ;;
        -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Okänt argument: ${arg}" >&2; exit 2 ;;
    esac
done

HOST="$(hostname)"

log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "${line}" >> "${LOG_FILE}" 2>/dev/null || true
    (( VERBOSE )) && echo "${line}"
    return 0
}

send_discord() {
    local message="$1"
    if (( DRY_RUN )); then
        echo "[dry-run] Skulle skicka: ${message}"
        return 0
    fi
    if [[ -z "${DISCORD_WEBHOOK_URL}" ]]; then
        log "WARNING: ingen DISCORD_WEBHOOK_URL i ${CONFIG_FILE} - inget skickat"
        echo "VARNING: ingen webhook konfigurerad (${CONFIG_FILE})" >&2
        return 1
    fi
    local payload
    # jq bygger korrekt JSON (citattecken och radbrytningar escapas)
    payload=$(jq -n --arg c "${message}" '{content: $c}')
    # URL:en skickas via stdin (-K -) så att den inte syns i processlistan (ps)
    if printf 'url = "%s"\n' "${DISCORD_WEBHOOK_URL}" \
        | curl -fsS -m 10 -K - -H 'Content-Type: application/json' -d "${payload}" >/dev/null; then
        log "Discord-meddelande skickat"
        return 0
    fi
    log "ERROR: kunde inte skicka till Discord"
    echo "FEL: kunde inte skicka till Discord (kontrollera webhook-URL och internet)" >&2
    return 1
}

# CPU i procent: två mätningar av /proc/stat med 1 sekunds mellanrum
cpu_usage() {
    local u1 n1 s1 i1 w1 x1 y1 z1 u2 n2 s2 i2 w2 x2 y2 z2
    read -r _ u1 n1 s1 i1 w1 x1 y1 z1 _ < /proc/stat
    sleep 1
    read -r _ u2 n2 s2 i2 w2 x2 y2 z2 _ < /proc/stat
    local idle=$(( (i2 + w2) - (i1 + w1) ))
    local total=$(( (u2 + n2 + s2 + i2 + w2 + x2 + y2 + z2) - (u1 + n1 + s1 + i1 + w1 + x1 + y1 + z1) ))
    (( total > 0 )) || { echo 0; return; }
    echo $(( (100 * (total - idle)) / total ))
}

# Antal misslyckade SSH-försök senaste 5 minuterna (fel nyckel, okänd användare)
ssh_failures() {
    journalctl -u ssh -u sshd --since "-5 min" --no-pager -q 2>/dev/null \
        | grep -cE "Invalid user|Failed (password|publickey)|Connection closed by authenticating user|Disconnected from authenticating user" \
        || true
}

# --- Testläge -----------------------------------------------------------------
if (( TEST )); then
    if send_discord ":white_check_mark: Testmeddelande från **${HOST}** ($(date '+%Y-%m-%d %H:%M:%S %Z')). Övervakningen fungerar."; then
        echo "Testmeddelande skickat - kontrollera Discord-kanalen."
        exit 0
    fi
    exit 2
fi

# --- Mätningar ----------------------------------------------------------------
problems=()

disk=$(df --output=pcent / | tail -n1 | tr -dc '0-9')
cpu=$(cpu_usage)
mem=$(awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf "%d", (t-a)*100/t}' /proc/meminfo)
ssh_fail=$(ssh_failures)

(( disk >= DISK_THRESHOLD )) && problems+=("Disk ${disk}% >= ${DISK_THRESHOLD}%")
(( cpu  >= CPU_THRESHOLD ))  && problems+=("CPU ${cpu}% >= ${CPU_THRESHOLD}%")
(( mem  >= MEM_THRESHOLD ))  && problems+=("RAM ${mem}% >= ${MEM_THRESHOLD}%")
(( ssh_fail >= SSH_FAIL_THRESHOLD )) && problems+=("${ssh_fail} misslyckade SSH-inloggningar senaste 5 min")

http_code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' "${API_URL}" || true)
[[ "${http_code}" == "200" ]] || problems+=("API svarar inte: ${API_URL} -> HTTP ${http_code:-000}")

if ! supervisorctl status fastapi_app 2>/dev/null | grep -q RUNNING; then
    problems+=("Supervisor: fastapi_app är inte RUNNING")
fi
for svc in nginx postgresql; do
    systemctl is-active --quiet "${svc}" 2>/dev/null || problems+=("Tjänsten ${svc} är inte active")
done

summary="Disk ${disk}%, CPU ${cpu}%, RAM ${mem}%, SSH-fel ${ssh_fail}, API HTTP ${http_code:-000}"

# --- Larm (utan spam) ---------------------------------------------------------
# Samma larm skickas igen tidigast efter REALERT_MINUTES. När allt blir OK igen
# skickas ett "återställt"-meddelande.
now=$(date +%s)
last_status="OK"; last_sent=0; last_text=""
if [[ -r "${STATE_FILE}" ]]; then
    IFS='|' read -r last_status last_sent last_text < "${STATE_FILE}" || true
fi

if (( ${#problems[@]} > 0 )); then
    text=$(printf '%s; ' "${problems[@]}")
    log "WARNING: ${text}(${summary})"
    if [[ "${last_status}" != "ALERT" || "${text}" != "${last_text}" ]] \
        || (( now - ${last_sent:-0} >= REALERT_MINUTES * 60 )); then
        msg=":rotating_light: **LARM på ${HOST}**"$'\n'
        for p in "${problems[@]}"; do msg+="- ${p}"$'\n'; done
        msg+="Tid: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        if send_discord "${msg}"; then
            (( DRY_RUN )) || echo "ALERT|${now}|${text}" > "${STATE_FILE}" 2>/dev/null || true
        fi
    else
        log "Samma larm redan skickat, väntar (REALERT_MINUTES=${REALERT_MINUTES})"
    fi
    (( VERBOSE )) && echo "Status: PROBLEM"
    exit 1
fi

log "OK: System healthy (${summary})"
if [[ "${last_status}" == "ALERT" ]]; then
    send_discord ":white_check_mark: **Återställt på ${HOST}**: ${summary}" || true
fi
(( DRY_RUN )) || echo "OK|${now}|" > "${STATE_FILE}" 2>/dev/null || true
(( VERBOSE )) && echo "Status: OK"
exit 0

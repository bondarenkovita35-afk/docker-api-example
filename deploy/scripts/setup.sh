#!/usr/bin/env bash
# =============================================================================
# setup.sh - grundinstallation av en ny Ubuntu 24.04-server (AWS EC2)
#
# Kopieras till servern med scp och körs:   sudo bash ~/setup.sh
#
# Gör:
#   1. Uppdaterar paket (apt update + upgrade)
#   2. Installerar Python, venv, pip, PostgreSQL, Supervisor, Nginx, Git,
#      fail2ban, logrotate och verktyg
#   3. Skapar tjänsteanvändaren "fastapi_service" som kör API:t
#   4. Skapar kataloger för loggar, backuper och hemligheter
#   5. Lägger till Bash-alias för alla användare
#   6. Härdar SSH (bara nycklar, ingen root-inloggning)
#   7. Slår på fail2ban (blockerar IP-adresser som gissar SSH-inloggningar)
#   8. Slår på brandväggen UFW (bara SSH och HTTP)
#   9. Logrotate, swap och kontroll av installationen
#
# Säkert att köra flera gånger (idempotent).
# =============================================================================

# -E: ERR-trap ärvs av funktioner, -e: avbryt vid fel,
# -u: fel vid odefinierad variabel, -o pipefail: fel i en pipe räknas
set -Eeuo pipefail
trap 'echo -e "\n\033[0;31m[FEL]\033[0m setup.sh stoppade på rad $LINENO: $BASH_COMMAND" >&2' ERR

APP_USER="fastapi_service"
APP_HOME="/home/${APP_USER}"
APP_LOG_DIR="/var/log/fastapi_app"
CONFIG_DIR="/etc/fastapi_app"
BACKUP_DIR="/var/backups/fastapi_app"

PACKAGES=(
    python3 python3-venv python3-pip   # Python, virtuella miljöer, pakethanterare
    postgresql postgresql-contrib      # databas
    supervisor                         # process manager för API:t
    nginx                              # reverse proxy
    git                                # versionshantering
    fail2ban                           # skydd mot SSH-attacker
    logrotate                          # roterar loggar
    ufw                                # brandvägg
    cron                               # schemaläggning
    curl jq                            # HTTP-anrop och JSON (monitor_system.sh)
    openssl ca-certificates            # slumplösenord, certifikat
    tree htop unzip                    # praktiska verktyg
)

log()  { echo -e "\n\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $*"; }
ok()   { echo -e "    \033[0;32m[OK]\033[0m $*"; }
warn() { echo -e "    \033[1;33m[VARNING]\033[0m $*"; }

# --- 0. Kontroller ------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "Kör skriptet med sudo:  sudo bash $0" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive   # inga frågor från apt
APT_OPTS=(-y -o DPkg::Lock::Timeout=300 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

# På en helt ny EC2 kan cloud-init fortfarande köra apt. Vänta tills det är klart.
if command -v cloud-init >/dev/null 2>&1; then
    log "Väntar på att cloud-init ska bli klar"
    cloud-init status --wait >/dev/null 2>&1 || true
fi

# --- 1. Uppdatera paket -------------------------------------------------------
log "1/9 Uppdaterar paketlistor och installerade paket"
apt-get update
apt-get "${APT_OPTS[@]}" upgrade
ok "Paket uppdaterade"

# --- 2. Installera program ----------------------------------------------------
log "2/9 Installerar paket"
apt-get "${APT_OPTS[@]}" install "${PACKAGES[@]}"
systemctl enable --now postgresql nginx supervisor cron
ok "Installerat: ${PACKAGES[*]}"

# --- 3. Tjänsteanvändare ------------------------------------------------------
log "3/9 Skapar tjänsteanvändaren ${APP_USER}"
# Varför? API:t ska inte köras som root eller ubuntu (som har sudo).
# Om någon hackar API:t får den bara rättigheterna för fastapi_service.
# Kontot har inget lösenord och inget sudo, så ingen kan logga in som det.
if id "${APP_USER}" >/dev/null 2>&1; then
    ok "${APP_USER} finns redan"
else
    useradd --system --create-home --home-dir "${APP_HOME}" --shell /bin/bash "${APP_USER}"
    ok "${APP_USER} skapad (hemkatalog ${APP_HOME}, inget lösenord, inget sudo)"
fi
chmod 750 "${APP_HOME}"

# --- 4. Kataloger och behörigheter -------------------------------------------
log "4/9 Skapar kataloger och sätter behörigheter"
# install -d skapar katalogen och sätter ägare/rättigheter i ett steg
install -d -m 755 -o "${APP_USER}" -g "${APP_USER}" "${APP_LOG_DIR}"   # API-loggar (Supervisor)
install -d -m 700 -o root -g root "${CONFIG_DIR}"                      # Discord-webhook
install -d -m 700 -o root -g root "${BACKUP_DIR}" "${BACKUP_DIR}/db" "${BACKUP_DIR}/logs"
ok "${APP_LOG_DIR} (755 ${APP_USER})"
ok "${CONFIG_DIR} (700 root) - för hemligheter"
ok "${BACKUP_DIR} (700 root) - bara root kan läsa backuper"

# --- 5. Bash-alias ------------------------------------------------------------
log "5/9 Installerar Bash-alias i /etc/profile.d/devops-aliases.sh"
# Filen skrivs om varje gång -> samma resultat vid omkörning
cat > /etc/profile.d/devops-aliases.sh <<'EOF'
# Bash-alias för DevOps-hemtentan (installerade av setup.sh)
alias ll='ls -alF'
alias la='ls -A'
alias ..='cd ..'
alias update='sudo apt update && sudo apt upgrade -y'
alias ports='sudo ss -tulpn'
alias diskfree='df -h /'
alias app='cd /home/fastapi_service/fastapi_app'
alias apistatus='sudo supervisorctl status fastapi_app'
alias apirestart='sudo supervisorctl restart fastapi_app'
alias apilogs='sudo tail -n 30 /var/log/fastapi_app/error.log'
alias health='curl -s http://127.0.0.1/status; echo'
alias ngtest='sudo nginx -t'
alias nglogs='sudo tail -n 30 /var/log/nginx/fastapi_access.log /var/log/nginx/fastapi_error.log'
alias dbshell='sudo -u postgres psql -d fastapi_movies_db'
alias backupnow='sudo /usr/local/bin/backup.sh'
alias monitornow='sudo /usr/local/bin/monitor_system.sh --verbose'
alias monlog='sudo tail -n 20 /var/log/system_monitor.log'
alias gs='git status'
EOF
chmod 644 /etc/profile.d/devops-aliases.sh
ok "Alias installerade (gäller från nästa SSH-inloggning, eller: source /etc/profile.d/devops-aliases.sh)"

# --- 6. SSH-härdning ----------------------------------------------------------
log "6/9 Härdar SSH"
# Filer i sshd_config.d läses i bokstavsordning, första värdet vinner -> 10- vinner.
# Samma inställningar som i lärarens guide, men i en egen fil i stället för att
# ändra /etc/ssh/sshd_config direkt.
cat > /etc/ssh/sshd_config.d/10-devops-hardening.conf <<'EOF'
# Installerad av setup.sh
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
chmod 644 /etc/ssh/sshd_config.d/10-devops-hardening.conf
# Testa konfigurationen INNAN omstart, annars kan vi låsa ute oss själva
if sshd -t; then
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
    ok "SSH: bara nyckelinloggning, root får inte logga in"
else
    rm -f /etc/ssh/sshd_config.d/10-devops-hardening.conf
    warn "sshd -t misslyckades, härdningsfilen togs bort (SSH oförändrat)"
fi

# --- 7. fail2ban --------------------------------------------------------------
log "7/9 Konfigurerar fail2ban"
# jail.local skapas bara första gången, så att egna ändringar inte skrivs över
if [[ ! -f /etc/fail2ban/jail.local ]]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi
systemctl enable --now fail2ban
ok "fail2ban aktiv (sshd-jail: blockerar IP efter för många misslyckade försök)"

# --- 8. Brandvägg -------------------------------------------------------------
log "8/9 Konfigurerar brandväggen UFW"
# VIKTIGT: tillåt SSH FÖRST, sedan aktivera, annars tappar vi anslutningen
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null           # HTTP (Nginx)
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw --force enable >/dev/null
ok "UFW aktiv: endast 22 (SSH) och 80 (HTTP) in. 8000 och 5432 är stängda."

# --- 9. Logrotate, swap, kontroll --------------------------------------------
log "9/9 Logrotate, swap och kontroll"
cat > /etc/logrotate.d/fastapi_app <<'EOF'
/var/log/fastapi_app/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    copytruncate
}

/var/log/system_monitor.log /var/log/fastapi_backup.log {
    weekly
    rotate 4
    compress
    delaycompress
    notifempty
    missingok
    create 0640 root adm
}
EOF
ok "/etc/logrotate.d/fastapi_app installerad"

mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if swapon --show --noheadings | grep -q .; then
    ok "Swap finns redan"
elif (( mem_kb < 2000000 )); then
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null
    swapon /swapfile
    grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    ok "1 GB swap skapad (hjälper när servern bara har 1 GB RAM)"
else
    ok "Tillräckligt med RAM, ingen swap behövs"
fi

errors=0
check_cmd() {
    local name="$1"; shift
    local out
    if out=$("$@" 2>&1); then
        ok "${name}: $(echo "${out}" | head -n1)"
    else
        warn "${name} saknas eller fungerar inte"
        errors=$((errors + 1))
    fi
}
check_cmd "Python"     python3 --version
check_cmd "venv"       python3 -c "import venv"
check_cmd "pip"        pip3 --version
check_cmd "Git"        git --version
check_cmd "Nginx"      nginx -v
check_cmd "PostgreSQL" psql --version
check_cmd "Supervisor" supervisorctl version
check_cmd "jq"         jq --version

for svc in postgresql nginx supervisor cron fail2ban ssh; do
    if systemctl is-active --quiet "${svc}"; then
        ok "Tjänsten ${svc} är active"
    else
        warn "Tjänsten ${svc} är INTE active"
        errors=$((errors + 1))
    fi
done

if (( errors > 0 )); then
    echo -e "\n\033[0;31m[FEL]\033[0m ${errors} kontroll(er) misslyckades. Läs varningarna ovan." >&2
    exit 1
fi

echo -e "\n\033[0;32mSETUP KLAR!\033[0m"

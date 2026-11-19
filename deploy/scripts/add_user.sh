#!/usr/bin/env bash
# =============================================================================
# add_user.sh - skapar ett eget Linux-konto för en student med SSH-nyckel
#
# Varför? Varje person loggar in med sitt eget konto och sin egen nyckel.
# Då syns i loggen vem som gjorde vad, och en nyckel kan tas bort utan att
# den andra studenten påverkas.
#
# Användning (på servern):
#   sudo bash add_user.sh <användarnamn> <fil-med-publik-nyckel.pub> [--sudo]
#
# Exempel:
#   sudo bash add_user.sh studentb /tmp/studentb.pub --sudo
#
# Endast den PUBLIKA nyckeln (.pub) kopieras till servern. Den privata nyckeln
# lämnar aldrig studentens egen dator.
# =============================================================================
set -Eeuo pipefail
trap 'echo "[FEL] add_user.sh rad $LINENO: $BASH_COMMAND" >&2' ERR

[[ $EUID -eq 0 ]] || { echo "Kör med sudo: sudo bash $0 ..." >&2; exit 1; }
[[ $# -ge 2 ]] || { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

USERNAME="$1"
KEYFILE="$2"
GIVE_SUDO="${3:-}"

# Linux-användarnamn: små bokstäver, siffror, - och _, börjar med bokstav
[[ "${USERNAME}" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] || { echo "Ogiltigt användarnamn: ${USERNAME}" >&2; exit 1; }
[[ -r "${KEYFILE}" ]] || { echo "Hittar inte nyckelfilen: ${KEYFILE}" >&2; exit 1; }

PUBKEY="$(head -n1 "${KEYFILE}" | tr -d '\r')"   # tr tar bort Windows-radslut
if [[ ! "${PUBKEY}" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))\ [A-Za-z0-9+/=]+ ]]; then
    echo "Filen ser inte ut som en publik SSH-nyckel (ska börja med ssh-ed25519 ...)" >&2
    echo "Har du råkat välja den PRIVATA nyckeln? Använd filen som slutar på .pub" >&2
    exit 1
fi

if id "${USERNAME}" >/dev/null 2>&1; then
    echo "[OK] Användaren ${USERNAME} finns redan"
else
    useradd --create-home --shell /bin/bash "${USERNAME}"
    echo "[OK] Användaren ${USERNAME} skapad"
fi

HOME_DIR="$(getent passwd "${USERNAME}" | cut -d: -f6)"
SSH_DIR="${HOME_DIR}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

# Rättigheter: SSH vägrar använda nycklar om katalogen/filen är för öppen
install -d -m 700 -o "${USERNAME}" -g "${USERNAME}" "${SSH_DIR}"
touch "${AUTH_KEYS}"
if grep -qxF "${PUBKEY}" "${AUTH_KEYS}"; then
    echo "[OK] Nyckeln finns redan i ${AUTH_KEYS}"
else
    echo "${PUBKEY}" >> "${AUTH_KEYS}"
    echo "[OK] Nyckeln tillagd i ${AUTH_KEYS}"
fi
chown "${USERNAME}:${USERNAME}" "${AUTH_KEYS}"
chmod 600 "${AUTH_KEYS}"
echo "[OK] Rättigheter: ${SSH_DIR} = 700, authorized_keys = 600"

if [[ "${GIVE_SUDO}" == "--sudo" ]]; then
    usermod -aG sudo "${USERNAME}"
    # Samma som ubuntu-användaren på EC2: sudo utan lösenord (kontot har inget lösenord)
    SUDOERS="/etc/sudoers.d/90-${USERNAME}"
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "${SUDOERS}.tmp"
    chmod 440 "${SUDOERS}.tmp"
    # visudo -c kontrollerar syntaxen. En trasig sudoers-fil kan låsa sudo helt.
    if visudo -cf "${SUDOERS}.tmp" >/dev/null; then
        mv "${SUDOERS}.tmp" "${SUDOERS}"
        echo "[OK] ${USERNAME} har sudo (${SUDOERS})"
    else
        rm -f "${SUDOERS}.tmp"
        echo "[FEL] sudoers-syntax fel, sudo inte tillagt" >&2
        exit 1
    fi
fi

echo
echo "Testa från studentens dator (Windows PowerShell):"
echo "  ssh -i \$HOME\\.ssh\\<nyckelnamn> ${USERNAME}@<Elastic-IP>"

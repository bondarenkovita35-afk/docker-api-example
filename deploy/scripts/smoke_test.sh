#!/usr/bin/env bash
# =============================================================================
# smoke_test.sh - snabbtest av API:ts endpoints
#
#   bash smoke_test.sh                        testar http://localhost (via Nginx)
#   bash smoke_test.sh http://127.0.0.1:8000  testar Uvicorn direkt
#   bash smoke_test.sh http://<Elastic-IP>    testar från en annan dator
#
# Skapar en testanvändare och tar bort den igen.
# =============================================================================
set -uo pipefail

BASE_URL="${1:-http://localhost}"
BASE_URL="${BASE_URL%/}"
pass=0; fail=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        echo "  [PASS] ${name} (HTTP ${actual})"; pass=$((pass + 1))
    else
        echo "  [FAIL] ${name} (förväntat ${expected}, fick ${actual})"; fail=$((fail + 1))
    fi
}

code() { curl -s -o /dev/null -m 5 -w '%{http_code}' "$@"; }

echo "Testar ${BASE_URL}"
check "GET /status"           200 "$(code "${BASE_URL}/status")"
check "GET /movies"           200 "$(code "${BASE_URL}/movies")"
check "GET /movie/1"          200 "$(code "${BASE_URL}/movie/1")"
check "GET /movie/999999"     404 "$(code "${BASE_URL}/movie/999999")"
check "GET /users"            200 "$(code "${BASE_URL}/users")"

# Skapa en testanvändare, läs id ur svaret: "User created successfully with id: 7"
username="smoketest_$(date +%s)"
body=$(curl -s -m 5 -X POST -H 'Content-Type: application/json' \
    -d "{\"username\":\"${username}\"}" -w '\n%{http_code}' "${BASE_URL}/users")
check "POST /users"           201 "$(tail -n1 <<<"${body}")"
user_id=$(head -n1 <<<"${body}" | grep -oE 'id: [0-9]+' | grep -oE '[0-9]+')

check "POST /users (fel data -> 422)" 422 "$(code -X POST -H 'Content-Type: application/json' -d '{}' "${BASE_URL}/users")"
if [[ -n "${user_id}" ]]; then
    check "DELETE /user/${user_id}" 200 "$(code -X DELETE "${BASE_URL}/user/${user_id}")"
fi
check "GET /docs"             200 "$(code "${BASE_URL}/docs")"
check "GET /openapi.json"     200 "$(code "${BASE_URL}/openapi.json")"

echo
echo "Resultat: ${pass} PASS, ${fail} FAIL"
[[ ${fail} -eq 0 ]]

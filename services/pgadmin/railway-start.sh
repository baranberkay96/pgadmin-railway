#!/usr/bin/env bash
# Railway start wrapper for pgAdmin 4 (written for this template).
#
# - Deploy-form values never fail the deploy (STANDARD 8.29): an invalid
#   login e-mail falls back to admin@{public domain}; a password shorter than
#   8 or longer than 128 characters locks the admin with a random password
#   nobody knows, and the log says how to fix it.
# - First start only: pre-registers the bundled Postgres (PRELOAD_PG_*) with
#   a .pgpass file, so the server opens without typing its password.
# - Every start: refreshes that .pgpass (the Postgres password stays in sync)
#   and, when PGADMIN_RESET_ADMIN=true or the admin was locked by this script,
#   sets the admin password from PGADMIN_DEFAULT_PASSWORD and unlocks it.
# - Then execs the image's /entrypoint.sh (it chowns the volume and runs
#   gunicorn as UID 5050).
set -u

log() { echo "railway-pgadmin: $*"; }

DATA=/var/lib/pgadmin
DB="$DATA/pgadmin4.db"
STATE="$DATA/.railway"
MIN_PW=8
MAX_PW=128

is_true() { case "${1:-}" in 1|true|TRUE|True|yes|YES|on|ON) return 0 ;; *) return 1 ;; esac; }

valid_email() {
    (cd /pgadmin4/pgadmin/utils && CHECK_EMAIL="$1" /venv/bin/python3 -c '
import os, sys
from validation_utils import validate_email
cfg = {"CHECK_EMAIL_DELIVERABILITY": False, "ALLOW_SPECIAL_EMAIL_DOMAINS": [], "GLOBALLY_DELIVERABLE": True}
sys.exit(0 if validate_email(os.environ["CHECK_EMAIL"], cfg) else 1)
' >/dev/null 2>&1)
}

random_pw() { /venv/bin/python3 -c 'import secrets; print(secrets.token_urlsafe(32))'; }

password_ok() { local n=${#1}; [ "$n" -ge "$MIN_PW" ] && [ "$n" -le "$MAX_PW" ]; }

# --- port and listener -------------------------------------------------------
case "${PORT:-}" in
    ''|*[!0-9]*) log "PORT='${PORT:-}' is not a number, using 5050"; PORT=5050 ;;
esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then log "PORT=$PORT out of range, using 5050"; PORT=5050; fi
export PORT
export PGADMIN_LISTEN_PORT="$PORT"
export PGADMIN_LISTEN_ADDRESS="[::]"
export PGADMIN_DISABLE_POSTFIX="${PGADMIN_DISABLE_POSTFIX:-true}"

mkdir -p "$STATE"

# --- admin e-mail -------------------------------------------------------------
EMAIL="$(printf '%s' "${PGADMIN_DEFAULT_EMAIL:-}" | tr -d '[:space:]')"
if [ -f "$DB" ] && [ -s "$STATE/admin-email" ]; then
    EMAIL="$(cat "$STATE/admin-email")"
elif [ -z "$EMAIL" ] || ! valid_email "$EMAIL"; then
    FALLBACK="admin@${RAILWAY_PUBLIC_DOMAIN:-pgadmin.example.org}"
    log "WARNING: PGADMIN_DEFAULT_EMAIL='${PGADMIN_DEFAULT_EMAIL:-}' is not a valid e-mail address; the admin login is $FALLBACK"
    EMAIL="$FALLBACK"
fi
export PGADMIN_DEFAULT_EMAIL="$EMAIL"

# --- admin password -----------------------------------------------------------
PW="${PGADMIN_DEFAULT_PASSWORD:-}"
unset PGADMIN_DEFAULT_PASSWORD_FILE
if [ ! -f "$DB" ]; then
    if password_ok "$PW"; then
        rm -f "$STATE/admin-locked"
    else
        log "WARNING: PGADMIN_DEFAULT_PASSWORD must be $MIN_PW-$MAX_PW characters (got ${#PW}). The admin is locked with a random password."
        log "Fix: set PGADMIN_DEFAULT_PASSWORD to $MIN_PW-$MAX_PW characters and redeploy; it is applied at the next start."
        PW="$(random_pw)"
        : > "$STATE/admin-locked"
    fi
    export PGADMIN_DEFAULT_PASSWORD="$PW"
    printf '%s' "$EMAIL" > "$STATE/admin-email"
    log "first start: creating the pgAdmin admin $EMAIL"
fi

# --- pre-registered Postgres server -------------------------------------------
pgpass_line() {
    # .pgpass needs ':' and '\' escaped
    local esc
    esc="$(printf '%s' "$PRELOAD_PG_PASSWORD" | sed -e 's/\\/\\\\/g' -e 's/:/\\:/g')"
    printf '%s:%s:*:%s:%s\n' "$PRELOAD_PG_HOST" "$PG_PORT" "$PRELOAD_PG_USER" "$esc"
}

PRELOAD_PG_HOST="${PRELOAD_PG_HOST:-}"
PRELOAD_PG_USER="${PRELOAD_PG_USER:-postgres}"
PRELOAD_PG_PASSWORD="${PRELOAD_PG_PASSWORD:-}"
PG_PORT="${PRELOAD_PG_PORT:-5432}"
case "$PG_PORT" in ''|*[!0-9]*) log "PRELOAD_PG_PORT='$PG_PORT' is not a number, using 5432"; PG_PORT=5432 ;; esac
STORAGE="$DATA/storage/${EMAIL//@/_}"

if [ -n "$PRELOAD_PG_HOST" ]; then
    umask 077
    pgpass_line > /tmp/railway-pgpass
    umask 022
    if [ ! -f "$DB" ]; then
        PRELOAD_PG_PORT="$PG_PORT" /venv/bin/python3 - > /tmp/railway-servers.json <<'PY'
import json, os
sslmode = os.environ.get("PRELOAD_PG_SSLMODE") or "prefer"
if sslmode not in ("disable", "allow", "prefer", "require", "verify-ca", "verify-full"):
    sslmode = "prefer"
server = {
    "Name": os.environ.get("PRELOAD_PG_NAME") or "Railway Postgres",
    "Group": "Railway",
    "Host": os.environ["PRELOAD_PG_HOST"],
    "Port": int(os.environ["PRELOAD_PG_PORT"]),
    "MaintenanceDB": os.environ.get("PRELOAD_PG_DB") or "postgres",
    "Username": os.environ.get("PRELOAD_PG_USER") or "postgres",
    "SSLMode": sslmode,
    "PassFile": "/.pgpass",
}
print(json.dumps({"Servers": {"1": server}}, indent=1))
PY
        chmod 644 /tmp/railway-servers.json
        export PGADMIN_SERVER_JSON_FILE=/tmp/railway-servers.json
        export PGPASS_FILE=/tmp/railway-pgpass
        log "first start: pre-registering Postgres server $PRELOAD_PG_HOST:$PG_PORT"
    elif [ -d "$STORAGE" ]; then
        install -m 600 -o 5050 -g 0 /tmp/railway-pgpass "$STORAGE/.pgpass" && log "refreshed .pgpass for $PRELOAD_PG_HOST"
    fi
fi
unset PRELOAD_PG_PASSWORD

# --- admin reset / unlock (existing installs) ---------------------------------
if [ -f "$DB" ] && { is_true "${PGADMIN_RESET_ADMIN:-false}" || [ -f "$STATE/admin-locked" ]; }; then
    if password_ok "$PW"; then
        log "resetting the password of $EMAIL from PGADMIN_DEFAULT_PASSWORD and unlocking it"
        if (cd /pgadmin4 && /venv/bin/python3 setup.py update-user "$EMAIL" --password "$PW" --active >/dev/null 2>&1) \
            && RESET_EMAIL="$EMAIL" /venv/bin/python3 -c '
import os, sqlite3
db = sqlite3.connect("/var/lib/pgadmin/pgadmin4.db")
db.execute("UPDATE \"user\" SET locked = 0, login_attempts = 0 WHERE email = ?", (os.environ["RESET_EMAIL"],))
db.commit()
'; then
            rm -f "$STATE/admin-locked"
            if is_true "${PGADMIN_RESET_ADMIN:-false}"; then
                log "admin password reset done; set PGADMIN_RESET_ADMIN=false so later password changes in the UI are kept"
            else
                log "admin password reset done; the admin is unlocked"
            fi
        else
            log "WARNING: admin password reset failed; the old password stays"
        fi
    else
        log "WARNING: PGADMIN_DEFAULT_PASSWORD must be $MIN_PW-$MAX_PW characters for a reset (got ${#PW}); nothing changed"
    fi
fi
unset PW PGADMIN_RESET_ADMIN

log "pgAdmin listens on [::]:$PORT, admin $EMAIL"
exec /entrypoint.sh "$@"

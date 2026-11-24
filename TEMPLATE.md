# pgAdmin 4 v9.19 with PostgreSQL 18: Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **pgAdmin 4 v9.19 with PostgreSQL 18** |
| Description | PostgreSQL admin web UI with login, plus a ready Postgres 18 database. (70 chars) |
| Category | Storage |
| Tags | pgadmin, postgresql, postgres, database, admin, gui, sql |
| Icon | `https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/pgadmin.svg` |
| Repo | `baranberkay96/pgadmin-railway`, service root `/services/pgadmin` |

## Base market templates (checked 2026-11-24)

| Code | Name | Total deploys | Stack | Problems |
|---|---|---|---|---|
| `h1EXJT` | pgAdmin | 218 | `dpage/pgadmin4:9`, volume, `/misc/ping` | Floating tag; runs everything as root (`RAILWAY_RUN_UID=0`); no database; an invalid e-mail or short password crash-loops the deploy |
| `pgadmin` | PgAdmin [Updated Nov '26] | 28 | `dpage/pgadmin4` (latest) | Unpinned, **no volume** (users and servers lost on every redeploy), no healthcheck |
| `pgadmin4` | PgAdmin 4 | 10 | `dpage/pgadmin4:latest`, volume | Unpinned, no healthcheck, no database |

Kept: pgAdmin image with a volume at `/var/lib/pgadmin`, `/misc/ping` healthcheck, Postfix disabled, admin from `PGADMIN_DEFAULT_EMAIL`/`PGADMIN_DEFAULT_PASSWORD`.

## Improvements over market templates

1. **Ships with the database it manages** (Postgres 18, private only), already registered in pgAdmin with a `.pgpass` file, so the one-click deploy is useful immediately.
2. **Pinned versions** (pgAdmin 9.19.0 and Postgres 18.7 by digest).
3. **pgAdmin never runs as root**: the container starts as root only so the upstream entrypoint chowns the Railway volume, then drops to UID 5050 with su-exec.
4. **Deploy-form values never fail the deploy** (STANDARD 8.29): invalid e-mail → `admin@{public domain}` with a log line; password outside 8-128 chars → admin locked with a random password, fixed by setting a valid one and redeploying.
5. **Admin reset/unlock** from variables (`PGADMIN_RESET_ADMIN=true`), using pgAdmin's own CLI.
6. Hardening: HTTPS-only session cookie, upgrade check off, 5-attempt lockout, Postfix off.

## Pinned versions

| Service | Source | Version | Released | Checked |
|---|---|---|---|---|
| pgAdmin | `dpage/pgadmin4:9.19.0@sha256:3591b3d0…0c83` + `railway-start.sh` | 9.19 | 2026-10-29 | 2026-11-24 |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18.7@sha256:0abac5c0…7089` | 18.7 | Railway base | 2026-11-24 |

## Services

### pgAdmin

- Source: repo build (`services/pgadmin/Dockerfile`), start script `railway-start.sh` → upstream `/entrypoint.sh`.
- Public domain, `targetPort` 5050, `PORT=5050`, healthcheck `/misc/ping` (300 s), restart `ON_FAILURE` ×10, volume `/var/lib/pgadmin`.
- One replica (pgAdmin supports a single gunicorn worker; SQLite settings DB on the volume).

### Postgres

Railway base service (`_railway-base/postgres.json` values), volume `/var/lib/postgresql/data`, private only, no TCP proxy.

## Resource estimate

Measured on the test deploy (2026-11-24, idle after login, connecting to the pre-registered server and listing databases): pgAdmin 210-245 MiB, Postgres ~100 MiB, CPU < 0.06 vCPU.

| Service | Idle RAM | Typical RAM | CPU |
|---|---|---|---|
| pgAdmin | 230 MB | 300-600 MB (query tool, large result grids, pg_dump) | 0.05 idle, up to 1 during exports |
| Postgres | 100 MB | 200-500 MB | 0.01-0.3 |

Estimated cost: idle ≈ $3.5/month (0.33 GB RAM + ~0.5 GB volumes); typical ≈ $5-10/month. Minimum plan: **Trial** runs it (both services far under 1 GB; pgAdmin could hit the Free plan's 0.5 GB on large result sets). Hobby recommended for real data (5 GB volumes).

## Verification checklist

- [x] Both services SUCCESS; `/misc/ping` 200 through the public domain.
- [x] Login with the generated credentials → `/browser/`; wrong password stays on `/login`.
- [x] Server group "Railway" with "Railway Postgres" pre-registered; connect works without typing a password (.pgpass); databases `postgres`, `railway` listed.
- [x] Redeploy: settings DB and server kept, `.pgpass` refreshed.
- [x] `PGADMIN_DEFAULT_PASSWORD=abc` + `PGADMIN_RESET_ADMIN=true`: deploy SUCCESS, warning logged, nothing changed.
- [x] Valid new password + `PGADMIN_RESET_ADMIN=true`: login with the new password works.
- [x] Fresh deploy with e-mail `not-an-email` and password `abc` (STANDARD 8.29): deploy SUCCESS, admin `admin@{domain}` locked with a random password, warnings logged; setting a valid password and redeploying unlocked it automatically; login and server connect worked.
- [x] Post-publish deploy by the real template id: PASS (2026-11-24).

## Open questions

- Password-reset e-mails need SMTP (Railway Pro); not configured.

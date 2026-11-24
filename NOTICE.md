# NOTICE: pgAdmin template

## Software deployed

| Component | Licence | Source |
|---|---|---|
| pgAdmin 4 v9.19 | PostgreSQL Licence (© The pgAdmin Development Team) | https://github.com/pgadmin-org/pgadmin4, image `dpage/pgadmin4:9.19.0`, used unmodified |
| PostgreSQL 18 | PostgreSQL Licence | Railway's `ghcr.io/railwayapp-templates/postgres-ssl` image |

## Written for this template

- `services/pgadmin/Dockerfile`, `services/pgadmin/railway-start.sh`, `template.json`, `README.md`, `TEMPLATE.md`, this file. MIT, © 2026 the template author.
- The start script only sets environment variables for the image's own `/entrypoint.sh`, writes a `servers.json` and `.pgpass` in the documented formats, and calls pgAdmin's own `setup.py update-user` CLI for the optional admin reset (plus one SQL `UPDATE` that clears the lock flags, as pgAdmin's user management does).

## Upstream sources checked (2026-11-24, read only; nothing was executed locally)

- `pgadmin-org/pgadmin4` at tag `REL-9_19`: `pkg/docker/entrypoint.sh` (first-start setup, e-mail validation, `PGADMIN_SERVER_JSON_FILE`, `PGPASS_FILE`, PUID/su-exec handling), `web/setup.py` (`update-user`), `web/pgadmin/setup/user_info.py`, `web/pgadmin/tools/user_management/__init__.py` (lock flags).
- pgAdmin container deployment documentation (environment variables, `servers.json` format).
- Docker Hub: `dpage/pgadmin4:9.19.0` index digest; GHCR: `railwayapp-templates/postgres-ssl:18.7` index digest.

## Market templates reviewed

`h1EXJT` (pgAdmin), `pgadmin` (PgAdmin [Updated Nov '26]), `pgadmin4` (PgAdmin 4): read for topology and variables only. Nothing was copied.

## Names and affiliation

pgAdmin is a project of the pgAdmin Development Team; PostgreSQL is a trademark of the PostgreSQL Community Association. This is a community template, not affiliated with or endorsed by either.

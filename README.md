# Deploy and Host pgAdmin with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/pgadmin-4-v919-with-postgresql-18?referralCode=20H68q)

pgAdmin 4 is the most widely used open-source administration and development tool for PostgreSQL. This template deploys pgAdmin 4 v9.19 behind its own login, together with a PostgreSQL 18 database that is already registered in pgAdmin, so you can browse tables and run SQL a few minutes after you click deploy.

## About Hosting pgAdmin

pgAdmin is a Python web application (Flask on gunicorn) that keeps its own users, saved servers and preferences in a small SQLite database. Hosting it means running the web service on a persistent volume, creating an admin account before anyone else can reach the page, and giving it a network path to your databases. On Railway, pgAdmin reaches any Postgres in the same project over the private network (`{service}.railway.internal`), so database ports do not need to be exposed to the internet. This template pins pgAdmin and Postgres to exact image digests, creates the admin from template variables, pre-registers the bundled Postgres with a password file, and turns off pgAdmin's local mail server and upgrade check.

## Common Use Cases

- Browse and edit tables, views and functions of a Railway Postgres without installing a desktop client
- Run and save SQL queries, use EXPLAIN visualisation and the ERD tool
- Back up and restore databases with pg_dump / pg_restore (the image ships client tools for Postgres 13-18)
- Give teammates their own pgAdmin accounts with separate saved servers
- Manage roles, extensions and permissions on several Postgres servers from one place

## Dependencies for pgAdmin Hosting

- pgAdmin 4 web application (`dpage/pgadmin4` image)
- A PostgreSQL server to manage (bundled: PostgreSQL 18)
- A persistent volume for pgAdmin's settings database and file storage

### Deployment Dependencies

- pgAdmin documentation: https://www.pgadmin.org/docs/pgadmin4/latest/
- pgAdmin container deployment: https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html
- pgAdmin source: https://github.com/pgadmin-org/pgadmin4
- Railway private networking: https://docs.railway.com/guides/private-networking

### Implementation Details

| Service | Image | Purpose | Public |
|---|---|---|---|
| pgAdmin | `dpage/pgadmin4:9.19.0` (digest-pinned) + small start script | Web UI, port 5050, volume `/var/lib/pgadmin` | HTTPS domain |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:18.7` (digest-pinned) | Database, volume `/var/lib/postgresql/data` | No (private network only) |

**First login**

1. In the deploy form, enter your e-mail in `PGADMIN_DEFAULT_EMAIL`. This is your login name.
2. After the deploy, open the pgAdmin service, copy `PGADMIN_DEFAULT_PASSWORD` from its Variables tab and open the public domain.
3. Expand **Servers → Railway → Railway Postgres**. The password is already stored, so the database opens directly.

The e-mail and password are applied on the **first start only**; pgAdmin keeps them in its own database afterwards. If the e-mail you typed is not a valid address, the admin becomes `admin@{your-pgadmin-domain}` and the deploy log says so. A password shorter than 8 characters locks the admin with a random password (the log explains it); set a longer one and redeploy.

**Forgot the password or locked out?** Set `PGADMIN_RESET_ADMIN=true` (and, if you like, a new `PGADMIN_DEFAULT_PASSWORD`), redeploy, log in, then set `PGADMIN_RESET_ADMIN` back to `false`. After 5 failed logins pgAdmin locks an account; the same reset unlocks it.

**Connect pgAdmin to another Railway database**

- Same project: in pgAdmin choose *Register → Server*, host `{postgres-service}.railway.internal`, port `5432`, and the user/password from that service's Variables tab.
- Another project or provider: enable a TCP proxy on that database and use its public host and port with SSL mode `require`.
- To pre-register a different server instead of the bundled one, change the `PRELOAD_PG_*` variables **before the first deploy** (they only seed a new pgAdmin volume). Set `PRELOAD_PG_HOST` to empty to pre-register nothing. You can delete the bundled Postgres service if you do not need it.

**Connect your apps to the bundled Postgres**: reference `${{Postgres.DATABASE_URL}}` in your app's variables. The database has no public port; enable a TCP proxy on the Postgres service if you need to reach it from outside Railway.

**Scaling and upgrades**: pgAdmin runs as one gunicorn worker by design (its session handling needs it); give it more threads with `GUNICORN_THREADS` rather than replicas. To upgrade, change the image tag and digest in `services/pgadmin/Dockerfile` of your copy of the repo; pgAdmin migrates its settings database on start. Postgres major upgrades (18 → 19) need a dump and restore.

**Security notes**: only pgAdmin is public, and only behind its login. Session cookies are HTTPS-only, the upgrade check is off, and Postfix is not started (password-reset mails need SMTP, which Railway allows on Pro plans). This is a community template and is not affiliated with the pgAdmin Development Team.

### Why Deploy pgAdmin on Railway?

Railway runs pgAdmin and Postgres side by side on a private network, with persistent volumes, HTTPS and logs handled for you. You get a full browser-based Postgres workbench next to your databases in one click, without opening database ports to the internet or maintaining a server.

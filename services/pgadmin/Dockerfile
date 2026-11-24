# syntax=docker/dockerfile:1
#
# pgAdmin 4 for Railway: the official upstream image, unmodified, plus
# railway-start.sh (written for this template). The script checks the
# deploy-form values (they never fail the deploy), pre-registers the bundled
# Postgres on the first start, can reset/unlock the admin account, and then
# hands over to the image's own /entrypoint.sh.
#
# Upstream: https://github.com/pgadmin-org/pgadmin4 (PostgreSQL Licence),
# image dpage/pgadmin4, tag 9.19.0 (released 2026-10-29), pinned by
# multi-arch index digest (checked 2026-11-24).
FROM dpage/pgadmin4:9.19.0@sha256:3591b3d02910dcd817dec6fcaa681c278ba6966945283dd0ea0042731c330c83

# Start as root so the upstream entrypoint can chown the Railway volume
# (mounted root-owned) and then drop to the pgadmin user (UID 5050) with
# su-exec. pgAdmin itself never runs as root.
USER root

COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start.sh

# Syntax check at build time; fails the build instead of the deploy.
RUN bash -n /usr/local/bin/railway-start.sh

ENV PORT=5050
EXPOSE 5050

ENTRYPOINT ["/usr/local/bin/railway-start.sh"]

#!/usr/bin/env bash
# Postgres backup for MyTravelPal — dumps the Fly Postgres cluster
# and uploads the compressed dump to a Fly Volume (mounted at
# /data/backups inside the API machine).
#
# Usage:
#   Local run (with a valid DATABASE_URL env var):
#     ./backup_postgres.sh
#
#   From a scheduled Fly machine job (recommended):
#     fly machines exec <machine> "bash /app/scripts/backup_postgres.sh"
#
# What it does:
# - `pg_dump` in custom format (parallel-restore ready, compressed).
# - Writes to `/data/backups/mytravelpal-<UTC-ISO>.dump`.
# - Keeps last 14 dumps; older ones are pruned.
#
# Recovery:
#   pg_restore -h <host> -U <user> -d <db> mytravelpal-<ts>.dump
#
# NOTE: this is the MVP setup — one weekly cron via `fly-console` or
# a GitHub Action calling `fly machine exec`. Move to a proper
# managed backup (e.g. Fly Postgres flex automated snapshots + off-
# site S3 mirror) before we cross 1 000 users.

set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL is required}"

DEST_DIR="${BACKUP_DIR:-/data/backups}"
RETAIN=${BACKUP_RETAIN:-14}
mkdir -p "$DEST_DIR"

STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
OUT="${DEST_DIR}/mytravelpal-${STAMP}.dump"

# `postgres://` scheme works with pg_dump directly; strip any
# `?sslmode=disable` suffix that Fly Postgres appends because
# `pg_dump` reads sslmode from the URL query but some libpq
# versions warn about unknown params.
CLEAN_URL="${DATABASE_URL%%\?*}"

echo "[backup] $(date -u -Is) starting dump → ${OUT}"
pg_dump --no-owner --no-privileges --format=custom \
    --compress=9 \
    --file "$OUT" \
    "$CLEAN_URL"

# Retention: keep the newest N files, delete the rest.
find "$DEST_DIR" -maxdepth 1 -type f -name 'mytravelpal-*.dump' \
    -printf '%T@ %p\n' \
    | sort -rn \
    | awk -v keep="$RETAIN" 'NR>keep {print $2}' \
    | xargs -r rm -f

echo "[backup] $(date -u -Is) done. Retention: keep ${RETAIN} newest."
ls -1t "$DEST_DIR" | head -n "$RETAIN"

#!/bin/bash

# Usage
# ./db/setup.sh <environment>

export PGUSER="${POSTGRES_ADMIN_USER:-${POSTGRES_USER:-postgres}}"
export PGPASSWORD="${POSTGRES_PASSWORD:-postgres}"
export PGHOST="${POSTGRES_HOST:-localhost}"

psql -c "CREATE ROLE sqlbook_readonly WITH LOGIN PASSWORD '$POSTGRES_READONLY_PASSWORD';" || true
psql -d sqlbook_events_$1 -c "GRANT SELECT ON clicks TO sqlbook_readonly;"
psql -d sqlbook_events_$1 -c "GRANT SELECT ON page_views TO sqlbook_readonly;"
psql -d sqlbook_events_$1 -c "GRANT SELECT ON sessions TO sqlbook_readonly;"

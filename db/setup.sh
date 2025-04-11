#!/bin/bash

# Usage
# ./db/setup.sh <environment>

export PGUSER="${DATABASE_USER:-postgres}"
export PGPASSWORD="${DATABASE_PASSWORD:-postgres}"
export PGHOST="${DATABASE_HOST:-localhost}"

psql -c "CREATE ROLE sql_book_readonly WITH LOGIN PASSWORD 'password';" || true
psql -d sql_book_events_$1 -c "GRANT SELECT ON clicks TO sql_book_readonly;"
psql -d sql_book_events_$1 -c "GRANT SELECT ON page_views TO sql_book_readonly;"
psql -d sql_book_events_$1 -c "GRANT SELECT ON sessions TO sql_book_readonly;"

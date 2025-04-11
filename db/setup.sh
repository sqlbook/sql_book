#!/bin/bash

# Usage
# ./db/setup.sh <environment>

psql -U postgres -c "CREATE ROLE sql_book_readonly WITH LOGIN PASSWORD 'password';" || true
psql -U postgres -d sql_book_events_$1 -c "GRANT SELECT ON clicks TO sql_book_readonly;"
psql -U postgres -d sql_book_events_$1 -c "GRANT SELECT ON page_views TO sql_book_readonly;"
psql -U postgres -d sql_book_events_$1 -c "GRANT SELECT ON sessions TO sql_book_readonly;"

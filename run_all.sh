#!/usr/bin/env bash
# Runs the scripts in queries/ in order inside the Oracle container using SQL*Plus
# and writes the output of each one to results/<script>.txt.
#
# Usage:
#   ./run_all.sh                 run 00..11 in order (00b is NOT run by default)
#   ./run_all.sh 06_logical_optimization.sql    run one script (name with or without .sql)
#
# Environment:
#   CONTAINER   container name (default: oracle-free, same as docker-compose.yml)
#   CONNECT     connect string (default: app/app@//localhost:1521/FREEPDB1)
set -u

# DB_ENGINE may come from the environment or from .env.
ENV_FILE="$(dirname "${BASH_SOURCE[0]}")/.env"
if [ -z "${DB_ENGINE:-}" ] && [ -f "$ENV_FILE" ]; then
  DB_ENGINE="$(grep -E '^DB_ENGINE=' "$ENV_FILE" | tail -n 1 | cut -d= -f2)"
fi
case "${DB_ENGINE:-oracle}" in
  oracle) ;;
  postgres|mysql)
    echo "DB_ENGINE=$DB_ENGINE: the example scripts in queries/ are Oracle SQL/PL-SQL and cannot run on $DB_ENGINE as they are." >&2
    echo "See SETUP.md, section 'Porting to PostgreSQL / MySQL'." >&2
    exit 2 ;;
  *)
    echo "Unknown DB_ENGINE '$DB_ENGINE' (use oracle, postgres or mysql)." >&2
    exit 2 ;;
esac

CONTAINER="${CONTAINER:-oracle-free}"
CONNECT="${CONNECT:-app/app@//localhost:1521/FREEPDB1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUERIES="$ROOT/queries"
RESULTS="$ROOT/results"
mkdir -p "$RESULTS"

# Default order. 00b_reset_part3.sql is an optional undo of the part 3 logical
# optimization and is not part of the normal run; run it explicitly if needed.
DEFAULT_SCRIPTS=(
  00_reset.sql
  01_tables.sql
  02_data.sql
  03_denormalization.sql
  04_triggers.sql
  05_tests.sql
  06_logical_optimization.sql
  07_test_logical.sql
  08_generate_data.sql
  09_indexes.sql
  10_partitioning.sql
  11_test_partitioning.sql
)

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Container '$CONTAINER' is not running. Start it with: docker compose --profile oracle up -d" >&2
  exit 1
fi

if [ $# -ge 1 ]; then
  s="$1"
  case "$s" in *.sql) ;; *) s="$s.sql" ;; esac
  SCRIPTS=("$s")
else
  SCRIPTS=("${DEFAULT_SCRIPTS[@]}")
fi

total_errors=0
for s in "${SCRIPTS[@]}"; do
  if [ ! -f "$QUERIES/$s" ]; then
    echo "Missing script: queries/$s" >&2
    total_errors=$((total_errors + 1))
    continue
  fi
  out="$RESULTS/${s%.sql}.txt"
  echo ">>> $s"
  docker cp "$QUERIES/$s" "$CONTAINER:/tmp/$s" >/dev/null
  # EXIT at the end so sqlplus returns; the script itself may also contain EXIT.
  docker exec "$CONTAINER" bash -c \
    "printf 'SET ECHO ON\nSET SERVEROUTPUT ON SIZE UNLIMITED\n@/tmp/$s\nEXIT\n' | sqlplus -L -s '$CONNECT'" \
    >"$out" 2>&1
  n=$(grep -cE 'ORA-|PLS-|SP2-' "$out")
  echo "    -> results/${s%.sql}.txt   ORA-/PLS-/SP2- lines: $n"
  total_errors=$((total_errors + n))
done

echo
echo "Done. Total ORA-/PLS-/SP2- lines: $total_errors"
echo "Note: 05, 07 and 11 contain expected errors (ORA-200xx, ORA-02290, ...); run ./check_results.sh -v to compare them with expected_errors.txt."

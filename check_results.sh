#!/usr/bin/env bash
# Compares the primary Oracle errors in results/<script>.txt (written by run_all.sh)
# with expected_errors.txt. Exit code 0 = all PASS, 1 = at least one FAIL or missing file.
#
# Usage: ./check_results.sh [-v] [script_name]
#   -v           print the unexpected error lines with context
#   script_name  check only this script (with or without .sql)
# Environment:
#   RESULTS_DIR  directory with the result files (default: ./results)
#   EXPECTED     expected errors file (default: ./expected_errors.txt)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-$ROOT/results}"
EXPECTED="${EXPECTED:-$ROOT/expected_errors.txt}"
VERBOSE=0
ONLY=""
for a in "$@"; do
  case "$a" in
    -v) VERBOSE=1 ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *) ONLY="${a%.sql}" ;;
  esac
done
[ -f "$EXPECTED" ] || { echo "Missing $EXPECTED" >&2; exit 2; }

# Primary errors: line starts with ORA-/PLS-/SP2- (optionally "12/5 " prefix), minus continuations.
PRIMARY_RE='^([0-9]+/[0-9]+[[:space:]]+)?(ORA|PLS|SP2)-[0-9]+'
primary_lines() {  # prints "lineno:text"
  grep -nE "$PRIMARY_RE" "$1" | grep -vE '(ORA-06512|ORA-04088|ORA-06508)'
}
count_codes() {    # stdin: lines "n:text" -> "CODE:COUNT ..." sorted
  grep -oE '(ORA|PLS|SP2)-[0-9]+' | sort | uniq -c | awk '{printf "%s%s:%s", (n++?" ":""), $2, $1}'
}
norm_expected() {  # "A:1  B:2" or "-" -> sorted, single-spaced
  tr ' \t' '\n\n' <<<"$1" | grep -v '^$' | grep -vx -- '-' | sort | paste -sd' ' -
}

scripts=()
while read -r name rest; do
  case "$name" in ''|'#'*) continue ;; esac
  [ -n "$ONLY" ] && [ "$name" != "$ONLY" ] && continue
  scripts+=("$name|$rest")
done < "$EXPECTED"
if [ -n "$ONLY" ] && [ ${#scripts[@]} -eq 0 ]; then scripts+=("$ONLY|-"); fi

fail=0
printf '%-26s | %-45s | %-45s | %s\n' script expected actual result
for entry in "${scripts[@]}"; do
  name="${entry%%|*}"; exp_raw="${entry#*|}"
  file="$RESULTS_DIR/$name.txt"
  exp="$(norm_expected "$exp_raw")"
  if [ ! -f "$file" ]; then
    printf '%-26s | %-45s | %-45s | %s\n' "$name" "${exp:--}" "(missing file)" FAIL
    fail=1; continue
  fi
  lines="$(primary_lines "$file")"
  act="$(count_codes <<<"$lines")"
  # sort actual the same way as expected
  act="$(norm_expected "$act")"
  if [ "$exp" = "$act" ]; then res=PASS; else res=FAIL; fail=1; fi
  printf '%-26s | %-45s | %-45s | %s\n' "$name" "${exp:--}" "${act:--}" "$res"
  if [ "$VERBOSE" = 1 ] && [ "$res" = FAIL ]; then
    # codes whose actual count differs from expected
    for code in $(printf '%s\n%s\n' "$exp" "$act" | tr ' ' '\n' | grep -oE '(ORA|PLS|SP2)-[0-9]+' | sort -u); do
      e=$(tr ' ' '\n' <<<"$exp" | grep "^$code:" | cut -d: -f2); e=${e:-0}
      a=$(tr ' ' '\n' <<<"$act" | grep "^$code:" | cut -d: -f2); a=${a:-0}
      [ "$e" = "$a" ] && continue
      echo "    $code: expected $e, actual $a"
      grep -nE "^([0-9]+/[0-9]+[[:space:]]+)?$code" "$file" | grep -vE '(ORA-06512|ORA-04088|ORA-06508)' | cut -d: -f1 |
      while read -r ln; do
        echo "    --- $name.txt line $ln"
        sed -n "$((ln>3?ln-3:1)),$((ln+3))p" "$file" | sed 's/^/    | /'
      done
    done
  fi
done
echo
[ "$fail" = 0 ] && echo "All checks PASS" || echo "Some checks FAILED (run with -v for details)"
exit "$fail"

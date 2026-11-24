# .github/

## What the workflow does

`workflows/oracle-tests.yml` runs on every push and pull request:

1. Starts `gvenzl/oracle-free:slim` as a service container (user `app`/`app`) and waits until it is healthy.
2. Runs `./run_all.sh` (scripts 00 to 11) against it; `CONTAINER` is set to the service container name.
3. Runs `./check_results.sh -v`, which compares the primary Oracle errors in `results/<script>.txt` with
   `expected_errors.txt`.
4. Always uploads `results/` as the artifact `results`.

## How to read a failure

- Open the log of the "Check results" step: the table shows `script | expected | actual | PASS/FAIL`.
  With `-v` each differing code is listed with the surrounding lines of the result file.
- Download the `results` artifact for the full SQL*Plus output of every script.
- Typical causes: an unexpected `ORA-00942`/`PLS-` error (bug in a script), or a missing expected error
  (a trigger or constraint no longer fires). A missing result file means `run_all.sh` did not reach that script.
- Locally: `./run_all.sh && ./check_results.sh -v` (optional argument: one script name).

## Adding a test that raises an error on purpose

Edit `expected_errors.txt`: add or raise the `ORA-xxxxx:count` entry on the line of that script.
Count only the primary error of each stack (not `ORA-06512`, `ORA-04088`, `ORA-06508`). Mark the statement in
the script with `-- ERROR ORA-xxxxx (expected)` as the other tests do.

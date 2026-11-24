# results/

## Purpose

Holds **generated output**. `run_all.sh` writes one file per script (`<script>.txt`, for example
`05_tests.txt`) here. These files are git-ignored (see `.gitignore`); only this README and `.gitkeep` are tracked.
Use the output for your documentation and screenshots, and to compare with the expected values in `spec/`.

## Files

| File | Content |
|---|---|
| `<script>.txt` | Raw SQL*Plus output of one script (generated, not committed) |
| `results.md` (optional, yours) | Hand-written report in the format below (commit it only if your course wants it) |

## Automatic check

`./check_results.sh [-v] [script]` reads `results/<script>.txt`, counts only the primary ORA-/PLS-/SP2- error of
each stack (ORA-06512, ORA-04088 and ORA-06508 continuation lines are ignored) and compares the counts with
`expected_errors.txt`. It prints `script | expected | actual | PASS/FAIL` and exits non-zero on any FAIL or
missing file. CI uploads the whole `results/` folder as an artifact.

## Naming convention

`results/<script name without .sql>.txt`, same name as in `queries/`.

## Recommended report format

```markdown
# Results report

## Setup

| Item | Value |
|---|---|
| Database | Oracle Database 23ai Free (gvenzl/oracle-free:slim) |
| Connection | app/app@//localhost:1521/FREEPDB1 |
| Date | YYYY-MM-DD |
| Clean start | yes (`00_reset.sql`) |

## Step 5.2: manual change of IssueDate is rejected

SQL:
(code block with the statement)

Expected: `ORA-20001: IssueDate is copied from the invoice and cannot be changed manually`

Actual: (paste output)

Status: PASS

## Summary

| Script | Steps | Passed | Failed | Notes |
|---|---|---|---|---|
| 05_tests.sql | 12 | 12 | 0 | 3 expected errors |
| 07_test_logical.sql | 13 | 13 | 0 | |
```

Per step: the SQL, the expected result, the actual result and a status (PASS / FAIL / EXPECTED ERROR).
End with a summary table per script.

## How to adapt

Use your own step names; keep the four items per step. Count expected errors separately from real errors
(`run_all.sh` prints the number of `ORA-`/`PLS-`/`SP2-` lines per script).

## Related folders

- `queries/`: the scripts producing the output.
- `spec/`: the expected values.
- `explanations/`: where you quote results.

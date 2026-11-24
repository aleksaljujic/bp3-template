# CLAUDE.md

## What this repo is

A template for a university "Databases 3" project on Oracle Database 23ai Free (example model:
orders and invoicing). Pipeline: `inputs -> assignment -> prompt -> spec -> queries -> results -> explanations`.
Work follows the rulebook [`spec/00_spec_workflow.md`](spec/00_spec_workflow.md): spec first, human
approval, requirements R-xx, tasks K-xx, parallel subagents, integration run, review, human approval.
Use `/spec` to drive it.

## Folder map

| Path | Purpose |
|---|---|
| `inputs/` | Photos/scans of the student's documents and assignments (git-ignored); see `inputs/README.md` |
| `assignments/` | Generic assignments (task, deliverables, notes) |
| `prompts/` | Prompts that produce specs (`prompts/NN_x.md` -> `spec/NN_x.md`) |
| `spec/` | Rulebook `00_spec_workflow.md` and the specs (contract for the scripts) |
| `queries/` | SQL scripts `00`..`11`, `00b_reset_part3.sql`, example queries |
| `results/` | Generated output of `run_all.sh` (git-ignored except README and .gitkeep) |
| `explanations/` | Defense and study notes |
| `report/` | Master report `BP3_projekat.docx`; `STRUCTURE.md` maps its chapters to repo files |
| `.claude/` | Claude Code config: `/spec` skill, subagents, shared permissions |
| `run_all.sh`, `docker-compose.yml`, `.env.example`, `SETUP.md` | Runner, containers, setup guide |

## Run order and how to run

```
00_reset -> 01_tables -> 02_data -> 03_denormalization -> 04_triggers -> 05_tests
         -> 06_logical_optimization -> 07_test_logical -> 08_generate_data -> 09_indexes
         -> 10_partitioning -> 11_test_partitioning
```

`00b_reset_part3.sql` undoes 06 and is not part of the default run.

- Start the DB (human step): `docker compose --profile oracle up -d`, wait until healthy.
- Run everything: `./run_all.sh`. One script: `./run_all.sh 05_tests`. Output goes to `results/<script>.txt`.
- Connect string comes from `.env` (copy `.env.example`; defaults `app/app@//localhost:1521/FREEPDB1`,
  `APP_USER`, `APP_PASSWORD`). Container name: `CONTAINER` (default `oracle-free`).
- The shared database is used by one actor at a time. Never connect as SYS or another user.
- Do not start or stop Docker or touch the database unless the human asked for it.

## SQL conventions

- Files are ASCII only; comments in English. Header block `-- ====` with file name and one-sentence
  purpose; sections separated by `-- ----`.
- Every PL/SQL object ends with `/` on its own line. SQL statements contain no blank lines.
- Naming: `pk_<table>`, `fk_<abbr>_<target>`, `ck_<abbr>_<col>`, triggers `trg_`, procedures `p_`,
  packages `pkg_` (existing flag package: `pkg_denorm.g_cascade`: save old value, set TRUE,
  restore also in the exception handler).
- Labels: `D#` denormalization, `T#` triggers, `P#` procedures, `I#` indexes; the same label in SQL
  comments, explanations and assignments.
- `RAISE_APPLICATION_ERROR` ranges: `-20001..-20009` part 2, `-20010..-20019` part 3.
- Tests: header block with the expected result, then the statement, then a `SELECT` showing the
  outcome. A statement that must fail is marked `ERROR ORA-xxxxx (expected)` in its header. Any
  other error is a real problem. Test scripts end with `ROLLBACK`.
- Scripts must be re-runnable (reset first, guards, drop before create). Update `00_reset.sql` and
  `00b_reset_part3.sql` when adding objects.
- DDL commits implicitly in Oracle: `ROLLBACK` does not undo it (also for procedures that run DDL).
  State the side effect in the spec and restore state explicitly in tests.

## Report-driven updates

- `report/BP3_projekat.docx` is the master report; its chapters are the unit of work. Before a
  change, find the chapter in `report/STRUCTURE.md`; after it, update that chapter's status and
  remind the human to add a version row (next `X.Y`, date, description) to the report's change table.
- Keep the file name stable (no `_vX.Y`). Do not edit the `.docx` unless the human asks.
- Code in the report and in `queries/` must match (same labels D#, T#, P#, I#).

## Rules

- Follow `spec/00_spec_workflow.md`. The spec is the contract: change the spec (and its changelog)
  before changing code that deviates from it. Read existing code before writing or changing a spec.
- Only the human sets a spec `Approved` or `Verified`. Never approve on your own.
- Write only files you own in a task; report bugs in other files, do not fix them.
- Report test outcomes honestly: command and result; say "not run" when not run.
- Never commit `results/*.txt` or `.env`. No personal data, credentials or real schema names in
  committed files, specs, prompts or test data.
- Replace `> TODO:` placeholders only with real content; keep unresolved ones listed in Open questions.

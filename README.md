# Databases 3 Project Template (Oracle 23ai Free)

A ready-to-run template for a university "Databases 3" project on Oracle Database 23ai Free.
It contains a small working example (orders and invoicing), the scripts, the assignment
structure, defense/study notes, AI-assistant prompts and specs. You replace the example
with your own domain and keep the workflow.

> TODO: replace `<COURSE NAME>`, `<YOUR DOMAIN>` and `<DEADLINE>` placeholders across the repo.

## The three project parts

1. **Database design**: conceptual model, relational model (PK/FK marked), tables, test data.
2. **Denormalization**: break 2NF and 3NF on purpose (at least one example through 2+ levels)
   and keep the redundant data consistent with triggers.
3. **Optimization**
   - (a) Logical: two techniques, each with a trigger and/or stored procedure.
   - (b) Physical: at least two index types, execution plans before and after.
   - (c) Partitioning: one horizontal and one vertical example.

## Folder map

| Folder / file | Purpose |
|---|---|
| `inputs/` | Photos or scans of your own business documents and assignment pages; the start of a new project. Git-ignored except its README (what the agent does with them). |
| `assignments/` | Generic versions of the three assignments: task, deliverables checklist, notes. |
| `prompts/` | Reusable AI-assistant prompts used to produce the specs and scripts. |
| `spec/` | Detailed specs (requirements, test tables, acceptance checklists) the scripts are built from. |
| `queries/` | The SQL scripts `00`..`11`, run in order (and `joins_examples.sql`, `window_examples.sql`). |
| `results/` | Generated output of `run_all.sh`. Git-ignored. |
| `explanations/` | Defense and study notes: design, denormalization, optimization, code cheat sheet, normal forms and triggers. |
| `SETUP.md` | Setup guide: Docker, database engines, editor extensions, troubleshooting. |
| `docker-compose.yml`, `.env.example` | Containers for Oracle 23ai Free, PostgreSQL 17, MySQL 8.4 (compose profiles) and their settings. |
| `.vscode/extensions.json`, `.gitattributes` | Recommended VS Code extensions; LF line endings for `.sh` / `.sql`. |
| `run_all.sh` | Runs the scripts in order and writes `results/<script>.txt`. |
| `check_results.sh`, `expected_errors.txt` | Compares `results/*.txt` with the expected Oracle errors per script (PASS/FAIL, `-v` for details). |
| `report/` | Master report `BP3_projekat.docx` and `STRUCTURE.md` (chapter -> repo files map, status, version log). Its chapters drive project updates. |
| `diagrams/` | Mermaid diagrams for the report: one conceptual model per business document and the relational model after each part (viewing, Draw.io and PNG export in its README). |
| `.github/` | GitHub Actions workflow: runs `run_all.sh` and `check_results.sh` against an Oracle service container (see `.github/README.md`). |
| `.claude/`, `CLAUDE.md` | Claude Code setup: project instructions, the `/spec` skill (spec workflow), subagents `sql-writer`, `test-writer`, `reviewer`, shared permissions. |

## Workflow

```
assignment -> prompt -> spec -> queries -> results -> explanations
```

1. Read the **assignment** (`assignments/`) and list what must be delivered.
2. Adapt a **prompt** (`prompts/`) to your domain and give it to your AI assistant (or use it as your own checklist).
3. The prompt produces/refines a **spec** (`spec/`): exact requirements and expected test results.
4. Implement the **queries** (`queries/`) following the spec.
5. Run `./run_all.sh`; compare **results** (`results/`) with the expected values in the spec.
6. Write the **explanations** (`explanations/`) so you can defend every line.

The spec step has its own rulebook (status lifecycle, requirements R-xx, tasks K-xx, subagents, review, approval):
[`spec/00_spec_workflow.md`](spec/00_spec_workflow.md).

## Working with Claude Code

The spec workflow is configured for Claude Code:

- `CLAUDE.md`: project instructions (folder map, run order, SQL conventions, rules).
- `/spec <prompt or spec file> [phase]`: drives the pipeline (spec draft, requirements, tasks, parallel subagents, integration run, review, approval) and resumes from the spec's status.
- `.claude/agents/`: `sql-writer` and `test-writer` (write only the files they own) and `reviewer` (read-only).
- `.claude/settings.json`: shared permissions (`./run_all.sh`, `./check_results.sh`, `docker compose ps/logs`, read-only git commands).

Example: `/spec prompts/01_logical_optimization.md`. Claude stops after the spec draft and after the review; only you set a spec to `Approved` and `Verified`.

## Quick start

> **Full setup guide: [SETUP.md](SETUP.md)** (prerequisites, Oracle / PostgreSQL / MySQL, VS Code extensions, troubleshooting).
> The example scripts are Oracle SQL/PL-SQL; `run_all.sh` supports Oracle. SETUP.md has a porting table for PostgreSQL and MySQL.

```bash
cp .env.example .env            # optional: change passwords / ports
docker compose --profile oracle up -d   # wait until the container is healthy (docker ps)
./run_all.sh                    # runs queries/00 .. 11, writes results/*.txt
./check_results.sh -v           # PASS/FAIL per script against expected_errors.txt
```

The same run and check execute in CI on every push (`.github/workflows/oracle-tests.yml`).

Connect with any client (SQL*Plus, SQLcl, VS Code, DBeaver):

```
app/app@//localhost:1521/FREEPDB1
```

Or from the container: `docker exec -it oracle-free sqlplus app/app@//localhost:1521/FREEPDB1`.

Run a single script: `./run_all.sh 05_tests` (name with or without `.sql`).
Use another container name: `CONTAINER=my-oracle ./run_all.sh`.

## Run order

| # | Script | Part | What it does |
|---|---|---|---|
| 00 | `00_reset.sql` | all | Drops everything in the schema (re-runnable start). |
| 01 | `01_tables.sql` | 1 | Normalized tables and constraints. |
| 02 | `02_data.sql` | 1 | Small test data set. |
| 03 | `03_denormalization.sql` | 2 | Adds redundant columns D1-D3 and fills them. |
| 04 | `04_triggers.sql` | 2 | `pkg_denorm` flag package and triggers T1-T5. |
| 05 | `05_tests.sql` | 2 | Trigger tests with expected results, ends with ROLLBACK. |
| 06 | `06_logical_optimization.sql` | 3a | `Invoice.TotalAmount` (T6, T7) and Incoterm to CHECK constraint (P1). |
| 07 | `07_test_logical.sql` | 3a | Tests for 06. |
| 08 | `08_generate_data.sql` | 3b | Generates bulk data (about 50000 invoices). |
| 09 | `09_indexes.sql` | 3b | Indexes I1-I3 with plans before/after. |
| 10 | `10_partitioning.sql` | 3c | Horizontal (interval range) and vertical (view + INSTEAD OF) partitioning. |
| 11 | `11_test_partitioning.sql` | 3c | Tests for 10. |

`00b_reset_part3.sql` undoes the logical optimization of 06 (drops T6, T7, P1, the column and the
CHECK, restores the lookup table). It is not run by default: `./run_all.sh 00b_reset_part3`.

## Starting from photos of your own documents

You can start a new project from photos or scans of your business documents (orders, invoices,
delivery notes, ...) and of your course assignments. Claude Code reads images (JPG, PNG, PDF), so
it can derive the model from them. From the point where your `01_tables.sql` and `02_data.sql`
exist, the rest follows the normal `/spec` workflow.

1. Put the photos in `inputs/`: one file per business document, plus the assignment pages.
   Naming and what the agent does with each file: [`inputs/README.md`](inputs/README.md).
   Black out personal data (names, addresses, tax IDs) first. The folder contents are git-ignored.
2. Ask Claude Code, for example:

   ```text
   Read all images in inputs/. Fill the placeholders in assignments/*.md from the assignment
   pages. Then write spec/00_domain.md (Status: Draft): one entry per business document with
   its entities and attributes, the relational model with PK/FK, and open questions about
   anything unreadable or ambiguous. Follow spec/00_spec_workflow.md and stop for my approval.
   ```

3. Review `spec/00_domain.md` and set it to `Approved` yourself.
4. Ask Claude to replace the example: rewrite `queries/01_tables.sql` and `02_data.sql` from the
   approved spec, update `00_reset.sql`, the conceptual and relational diagrams in `diagrams/`
   and `explanations/01_database_design.md`, and remove the orders/invoicing example from
   `03`..`11`, `spec/`, `prompts/` and `expected_errors.txt`. If you want to keep the example as
   a reference, ask to move it to a separate folder instead of deleting it.
5. Part 2: ask for a spec that proposes the denormalizations (one 2NF, one 3NF through 2+
   levels, triggers) for your tables, then run `/spec spec/<that spec>.md`.
6. Part 3: adapt `prompts/01_logical_optimization.md` and `02_physical_optimization.md` to your
   tables and run `/spec prompts/01_logical_optimization.md` (and `02_...`).
7. Reset `report/STRUCTURE.md` (and, if you want it, ask for the `.docx` chapters) for your domain.

> Planned: a dedicated `prompts/00_from_documents.md` / `/new-project` skill that does steps 1-4
> in one command. Until then use the prompt above.

## Adapting the template to your own project

- [ ] Pick your domain; write the table list (like the table in `explanations/01_database_design.md`).
- [ ] Rewrite `queries/01_tables.sql` and `02_data.sql`; keep the naming conventions (`pk_`, `fk_`, `ck_`).
- [ ] Choose your denormalizations (D1..Dn): one 2NF, one 3NF through 2+ levels, one derived value.
- [ ] Rewrite `03` / `04` / `05`; keep `pkg_denorm.g_cascade`, error codes and the test style.
- [ ] Choose two logical techniques and adapt `06` / `07` / `00b`.
- [ ] Choose three index candidates from real queries, adapt `08` / `09`.
- [ ] Choose a table for range partitioning and one for vertical splitting; adapt `10` / `11`.
- [ ] Update `spec/` and `prompts/` to your names; regenerate the scripts from them if you use an AI assistant.
- [ ] Fill in the `> TODO:` notes in `explanations/`.
- [ ] Replace the placeholders in `assignments/` (course name, deadline, submission format).
- [ ] Run `./run_all.sh` from a clean container and check that every expected result matches.

## Notes

- **DDL commits implicitly** in Oracle. `ROLLBACK` does not undo `CREATE`, `ALTER`, `DROP` or procedures that run DDL (such as `p_change_incoterms`). Tests that use DDL must restore the state explicitly.
- **Scripts are re-runnable**: `00_reset.sql` cleans the schema, 08 is guarded against running twice, 09 and 10 drop before create.
- **Results are not committed**: `results/*.txt` is generated and git-ignored. Only `results/README.md` and `.gitkeep` are tracked.
- Expected errors (`ORA-200xx`, `ORA-02290`) appear in the output of 05, 07 and 11; `./check_results.sh` compares them with `expected_errors.txt`. When you add or change a test, update that file.
- SQL files are ASCII only, comments in English.
# bp3-template

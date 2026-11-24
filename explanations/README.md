# explanations/

## Purpose

Study and defense notes: for every script you should be able to say what it does and why.
These are templates written around the example orders/invoicing model. Replace the example
with your own model and fill in the `> TODO:` notes.

## Files

| File | Content |
|---|---|
| `01_database_design.md` | Part 1: domain, table list, constraints, test data, run order |
| `02_denormalization.md` | Part 2: D1-D3, why denormalize, the flag package, tests |
| `03_optimization.md` | Part 3: logical techniques, indexes I1-I3, partitioning |
| `04_code_for_defense.md` | Generic Oracle / PL/SQL cheat sheet (SQL*Plus, blocks, errors, triggers, plans, indexes, partitions) |
| `05_normal_forms_and_triggers.md` | Normal forms in plain words and all triggers T1-T7 plus the vertical-partition triggers |

## Naming convention

`01`..`03` match the assignments (`assignments/`). `04` and `05` are cross-cutting references.

## How to adapt

1. Replace the example tables, ids (D1, T1, I1, ...) and numbers with yours.
2. Keep the section structure: what is asked, scripts of the phase, per-item explanation, tests, run order.
3. Write each `> TODO:` note in your own words. If you cannot explain a line, you will not be able to defend it.

## Related folders

- `assignments/`: what is asked.
- `queries/`: the code explained here.
- `results/`: real output to quote in the explanations.
- `spec/`: exact requirements and expected values.

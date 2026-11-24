# spec/

## Purpose

A spec is the contract between you (or your AI assistant) and the scripts: exactly what each script
must contain, how it is tested, and what output is expected. Write or update the spec first; get it
approved; then implement; then check the results against it.
The rulebook for all specs is [00_spec_workflow.md](00_spec_workflow.md): read it first.

## Files

| File | Covers |
|---|---|
| `00_spec_workflow.md` | Rulebook: pipeline spec -> requirements (R-xx) -> tasks (K-xx) -> subagents -> integration/test -> review -> approve; status lifecycle; mandatory sections; subagent brief template; copy-paste skeleton |
| `01_logical_optimization.md` | `06_logical_optimization.sql`, `07_test_logical.sql`, `00b_reset_part3.sql` |
| `02_physical_optimization.md` | `08_generate_data.sql`, `09_indexes.sql`, `10_partitioning.sql`, `11_test_partitioning.sql` |

## Naming convention

`NN_topic.md`, matching the prompts in `prompts/` (`prompts/01_*.md` produces `spec/01_*.md`).
`00_spec_workflow.md` is the rulebook, not a spec.

## Status header

Every spec starts with:

```markdown
# Spec: <part>, <topic>
Status: Draft | Approved | Implemented | Verified
Source: prompts/NN_<topic>.md
Scripts: queries/NN_*.sql, ...
```

`Draft` (being written) -> `Approved` (human accepted the plan) -> `Implemented` (files exist) -> `Verified`
(tests passed, human approved the result). Only the human sets `Approved` and `Verified`.

## Mandatory sections (in this order)

0. Starting state and deviations (prompt says / actual state / decision)
1. Style
2..n. One section per deliverable file
- Requirements (`R-xx`, each testable)
- Tasks (`K-xx`, every R covered, file ownership disjoint)
- Test plan (step / action / exact expected result)
- Documentation content
- Acceptance checklist
- Open questions (options + recommendation)
- Changelog

The templates in this folder follow this structure with the orders/invoicing example filled in.

## How to adapt

Keep the sections, replace the example model with yours, and list real expected values (row counts,
error codes, plan operations). Mark open decisions with `> TODO:` and list them under Open questions.
Never edit code that deviates from the spec without updating the spec and its changelog first.

## Related folders

- `prompts/`: produce the specs.
- `queries/`: implement them.
- `results/`: actual output compared to the expected values; report format in `results/README.md`.
- `explanations/`: the specs are source material for the defense notes.

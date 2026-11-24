# assignments/

## Purpose

Generic, course-neutral versions of the three assignment documents. They list what must be
delivered for each project part. They are the starting point of the workflow
(assignment -> prompt -> spec -> queries -> results -> explanations).

## Files

| File | Part | Topic |
|---|---|---|
| `01_database_design.md` | 1 | Conceptual model (one diagram per document) and relational model |
| `02_denormalization.md` | 2 | 2NF and 3NF denormalization plus triggers |
| `03_optimization.md` | 3 | Logical optimization, indexes, partitioning |

## Naming convention

`NN_topic.md`, where NN is the project part (01..03). Same numbering is used in `explanations/`.

## How to adapt

Replace the placeholders (`<COURSE NAME>`, `<DEADLINE>`, `<SUBMISSION FORMAT>`) with the values
from your course. Keep the academic requirements; add anything your course requires on top.
Tick the deliverables checklist as you go.

## Related folders

- `prompts/` and `spec/`: turn the assignment into scripts.
- `explanations/`: one file per assignment, same numbering.
- `queries/`: the implementation.

# inputs/

## Purpose

Raw source material for starting a new project: photos or scans of the student's own business
documents (orders, invoices, delivery notes, ...) and of the course assignment pages. This is the
first step of the workflow, before `assignments/`:

```
inputs -> assignments + spec/00_domain.md -> queries/01_tables.sql, 02_data.sql -> /spec for parts 2 and 3
```

Everything in this folder except this `README.md` and `.gitkeep` is git-ignored.

## What the human puts here

| Kind | Naming | Example |
|---|---|---|
| Business document (one file per document type) | `doc_<name>.<ext>` | `doc_invoice.jpg`, `doc_delivery_note_2.png` |
| Assignment page | `assignment_<part>_<page>.<ext>` | `assignment_1_1.jpg`, `assignment_3_2.pdf` |
| Anything else (notes, mentor feedback) | `note_<topic>.<ext>` | `note_mentor_feedback.txt` |

Formats: JPG, PNG, PDF, TXT, MD. Several photos of one document: add a suffix (`doc_invoice_a.jpg`,
`doc_invoice_b.jpg`). Black out personal data (names, addresses, tax IDs, signatures) before
adding a file.

## What the agent does with it

1. **Read every file** in `inputs/` (images with the Read tool). List each file and what it is.
   If a file is unreadable or its kind is unclear, put it in Open questions; do not guess.
2. **Assignment pages -> `assignments/*.md`.** Replace the placeholders (`<COURSE NAME>`,
   `<DEADLINE>`, `<SUBMISSION FORMAT>`, multiple submissions) and add course-specific
   requirements under Notes. Keep the existing academic requirements; report conflicts.
3. **Business documents -> `spec/00_domain.md`** (`Status: Draft`, `Source: inputs/...`), built
   from the skeleton in `.claude/skills/spec/templates/spec_skeleton.md`:
   - one section per document: header fields, line-item fields, which fields are computed
     (totals, sums) and which are copied from other documents (candidates for denormalization
     in part 2);
   - the entities and attributes per document (one conceptual model per document, not one
     integral model);
   - the relational model: tables, columns, Oracle types, PK, FK, CHECK, with the naming rules
     of `CLAUDE.md` (`pk_`, `fk_`, `ck_`);
   - Open questions for every unreadable or ambiguous field, with a recommendation.
4. **STOP** and ask the human to review. Only the human sets `Approved`.
5. After approval, follow the human's instructions to replace the example (see "Starting from
   photos of your own documents" in the root `README.md`).

## Rules

- Never copy personal data from the photos into specs, SQL, test data or any committed file.
  Use invented but realistic values (`Customer 1`, `ACME d.o.o.`, made-up tax IDs).
- Never commit files from `inputs/` and never upload them to an external service.
- Do not edit or delete files in `inputs/`; they are the human's originals.
- Use the document's field names as the basis for column names, translated to English and
  written in the template's naming style; note the original label in the spec.

## Related folders

- `assignments/`: filled from the assignment pages.
- `spec/`: `00_domain.md` is the output of this step.
- `queries/`: `01_tables.sql` and `02_data.sql` are written from the approved domain spec.
- `diagrams/`: conceptual models per document and the relational model.

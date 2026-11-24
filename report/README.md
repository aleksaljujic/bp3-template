# report/

## Purpose

`BP3_projekat.docx` is the master project report (the document that is submitted). Its chapter
structure is the structure for updating the project: every change in the repo belongs to a
chapter, and every chapter update bumps the report version.

The file name is stable on purpose. The version lives in the report's own change table
(`Verzija | Datum promene | Opis promene`) and in git history, not in the file name.

## Files

| File | Purpose |
|---|---|
| `BP3_projekat.docx` | Master report. Edit this file only; never keep `_vX.Y` copies here. |
| `STRUCTURE.md` | Chapter map: chapter -> repo files -> status, and the version log. |

## Update procedure

1. Pick the chapter in `STRUCTURE.md` you are working on.
2. Change the repo files mapped to it (assignment -> prompt -> spec -> queries -> results ->
   explanations, see `spec/00_spec_workflow.md`).
3. Run `./run_all.sh` and `./check_results.sh`; copy the final SQL and test outcomes into the
   chapter. The report must show the same code as `queries/` (same labels D#, T#, P#, I#).
4. Add a row to the change table on the report's title page: next version (`1.6 -> 1.7`),
   date (`DD.MM.YYYY.`), one-line description.
5. Update the chapter status and the version log in `STRUCTURE.md`.
6. Commit the report and the repo changes together, e.g. `docs(report): v1.7 indexes (5.1)`.

## Submission copy

The course expects a versioned file name. Make the copy outside the repo (or in a git-ignored
place) when submitting:

```
BP3_<Ime>_<Prezime>_<indeks>_v<X.Y>.docx
```

## Notes

- The report contains personal data (name, student index) on the title page. Decide before
  pushing to a public remote whether this file is committed (see the privacy rule in
  `CLAUDE.md`).
- `.docx` is binary: git shows no diff. Describe each change in the change table and the commit
  message.

---
name: spec
description: Turn a prompt in prompts/ into a spec, requirements, tasks, parallel subagent work, an integration test, a review and a human approval, following spec/00_spec_workflow.md. Use when starting, continuing or reviewing the spec-driven implementation of a part of the project.
argument-hint: <prompt file or spec file, optional phase 1-7>
---

# /spec: spec-driven workflow

The rulebook is `spec/00_spec_workflow.md`. Read it fully before starting; this skill only
orders the steps and does not repeat the rules. Also read `CLAUDE.md` and `spec/README.md`.
Templates: `templates/spec_skeleton.md` (workflow section 10) and `templates/brief.md` (section 5.2),
both in this skill folder.

## Resuming from the argument

Argument: `<file> [phase]`.

- `prompts/NN_x.md` (no spec yet): start at phase 1.
- `spec/NN_x.md`: read its `Status:` line and which sections exist, then resume:
  `Draft` without Requirements -> phase 2; with Requirements but no Tasks -> phase 3;
  `Draft` complete -> phase 1 gate (ask for approval); `Approved` -> phase 4;
  `Implemented` -> phase 5; all tests passed -> phase 6/7.
- An explicit phase number overrides this. State which phase you start at and why.
- No argument: list `prompts/` and `spec/`, ask which one.

## Phase 1: spec draft

1. Read the prompt AND all existing code it touches (`queries/`, `explanations/`). Never trust the
   prompt's description of existing files.
2. Create `spec/NN_<topic>.md` from the skeleton. First lines: `Status: Draft`, `Source:`, `Scripts:`.
3. Fill section 0 (deviation table: prompt says / actual state / decision), section 1 (style), and one
   section per deliverable file with exact names, signatures, error codes, edge cases, side effects
   (implicit DDL commit, cascades, mutating tables).
4. Decide, do not survey: pick an option and give the reason; put only genuinely human choices in
   Open questions with a recommendation.
5. STOP. Show the human the deviation table, decisions and open questions and ask for approval.
   Do not continue until the human answers. Only the human sets `Approved`.

## Phase 2: requirements

Extract `R-xx` (MUST/SHOULD, source, acceptance, verified by). Each must be testable; IDs are never
renumbered. Add the Test plan (step / action / exact expected result, including expected errors).

## Phase 3: tasks

Write the `K-xx` table: covers, owns, reads, depends on, done when. Check: every R is covered,
file ownership is disjoint between parallel tasks, one to three files per task, integration is a
separate final task that depends on all others. Shared database use is serialized.

## Phase 4: subagents

Requires spec status `Approved` (set by the human). Then:

1. For each task without unmet dependencies, write a brief from `templates/brief.md` (self-contained:
   spec sections, owned files, files not to touch, decisions made, style, testing rules).
2. Launch in ONE message, in parallel, using the agent types:
   `sql-writer` (scripts), `test-writer` (test scripts), `general-purpose` for documentation tasks.
   Never two agents with the same owned file.
3. Tell subagents not to run against the database unless the brief says so; only one agent (or you)
   uses the shared database at a time.
4. Treat reports as claims. Collect deviations; each is reverted or written back to the spec first
   (with a changelog line). When all tasks are done, set `Status: Implemented`.

## Phase 5: integration

Only after the human has confirmed that the database may be used.

1. Run `./run_all.sh` (or the spec's run order). Do not start or stop containers on your own.
2. Count error lines per script; only errors listed in the test plan may appear.
3. Compare each test step with the exact expected result in the spec.
4. Run `./check_results.sh` if it exists. Check re-runnability (undo script, then rerun).
5. Never edit script files to make a failing result pass without going back through the spec (phase 3).
6. Report failures honestly: command, output, which R-xx is affected.

## Phase 6: review

Launch the `reviewer` agent with: spec path, changed files, results location, the checklist and
severity table of workflow section 7. It is read-only. Findings, most severe first, with file:line.
Any "must fix" returns you to phase 3 (new or reopened task), not to direct editing.

## Phase 7: approval

1. Present to the human: what was built, results table (expected vs actual), open "should fix" items,
   spec changes.
2. WAIT for an explicit "approved" or a change list. Do not infer approval.
3. On approval only: set `Status: Verified`, add a changelog line, update `explanations/`, and write
   the results report (format in `results/README.md`). Commit only if asked; never commit `results/*.txt`.

## Hard rules

- The human approves the spec (`Approved`) and the result (`Verified`); you never do.
- Write only files you own in the current task; never touch other agents' files (report bugs instead).
- Shared DB used serially; no Docker or database actions unless the human allows them.
- Update the spec (and changelog) before code that deviates from it.
- Report failures and unverified items honestly; say "not run" when not run.
- No personal data or credentials in any file.

## Checklist

- [ ] Phase and spec status stated at the start
- [ ] Code read before the spec; deviation table filled
- [ ] Human approved the spec before phase 4
- [ ] R-xx testable; K-xx cover all R, ownership disjoint
- [ ] Briefs self-contained; subagents launched in parallel
- [ ] Integration run compared with exact expected results
- [ ] Reviewer findings handled; no open "must fix"
- [ ] Human approved explicitly; status, changelog, explanations updated

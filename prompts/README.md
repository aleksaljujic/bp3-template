# prompts/

## Purpose

Reusable prompts for an AI coding assistant. Each prompt describes one piece of work precisely
enough that the assistant can produce a spec or the scripts without guessing.
They are written for the example orders/invoicing model and the file names of this template.

## How prompts are used

The full process (requirements, tasks, subagents, review, approval) is defined in
[`spec/00_spec_workflow.md`](../spec/00_spec_workflow.md).

```
prompt  ->  spec  ->  implementation  ->  test
```

1. Adapt the prompt (your table names, your techniques) and give it to the assistant together with the existing scripts.
2. The assistant reads all existing scripts first and writes or updates the **spec** in `spec/` (requirements and expected test results).
3. Review the spec. Fix it, not the code: the spec is the contract.
4. The assistant implements the scripts in `queries/` from the spec.
5. Run `./run_all.sh`, compare with the expected results in the spec, paste mismatches back to the assistant.

## Files

| File | Use |
|---|---|
| `01_logical_optimization.md` | Part 3a: two logical techniques with triggers/procedure, and tests |
| `02_physical_optimization.md` | Part 3b/3c: data generation, indexes, partitioning |
| `03_reduction.md` | Re-sync part 3 after the part 2 design changed (fewer/more denormalizations) |

## Naming convention

`NN_topic.md`, numbered in the order you would use them.

## How to adapt

- Replace the example table, column, trigger and procedure names with yours.
- Keep the structure: context, "do not modify existing files", technique-by-technique requirements, tests, constraints.
- State the style rules (language of comments, `/` after PL/SQL objects, naming conventions); assistants follow them literally.
- Add anything your course requires (for example, a number of rows or a specific index type).

## Related folders

- `spec/`: the output of the prompts.
- `queries/`: the scripts the specs describe.
- `assignments/`: the requirements the prompts must satisfy.

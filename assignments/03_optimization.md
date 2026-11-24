# <COURSE NAME>: 3. Database Optimization

| | |
|---|---|
| **Deadline** | `<DEADLINE>` |
| **Submission** | `<SUBMISSION FORMAT>`; multiple submissions allowed: `<yes/no>` |

> **Prerequisite:** the first two parts are approved.

## Task

### 1. Logical optimization of the model

Apply **two optimization techniques** to the designed model.

- Briefly explain why each technique was chosen.
- Illustrate with the changed database model.
- For each technique create an accompanying **stored procedure and/or trigger** that implements it.

> **Example:** if you choose *Hard Coded Values*, also implement a procedure that changes the
> constraint, i.e. the allowed set of values.

### 2. Physical optimization: indexes

- Define at least **two different index types** (e.g. B-tree, bitmap, function-based).
- Justify each index (which kind of query it speeds up).
- Illustrate with the **execution plan** of the query **before and after** creating the index.

### 3. Table partitioning

Show examples on the designed database:

- **horizontal** partitioning
- **vertical** partitioning

## Deliverables checklist

- [ ] Two logical techniques, each with reasoning, changed model, and trigger/procedure
- [ ] Two or more index types, each with query, plan before, plan after
- [ ] Horizontal partitioning example (partition pruning shown in a plan)
- [ ] Vertical partitioning example (model before/after, view and INSTEAD OF triggers if used)
- [ ] Test scripts and their output

## Notes

- Submit before the consultation with your mentor.
- Use a data set large enough for the optimizer to prefer the index (thousands of rows or more).
- `<ADD COURSE-SPECIFIC NOTES>`

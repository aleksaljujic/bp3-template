# Diagrams

The assignment requires a separate conceptual-model diagram for each business document and a relational model before and after each part. These files hold them as text diagrams (Mermaid), so they are versioned with the code and render on GitHub.

## Files

| File | Content |
|---|---|
| [01_document_sales_order.md](01_document_sales_order.md) | Conceptual model of the document "Sales order" |
| [01_document_invoice.md](01_document_invoice.md) | Conceptual model of the document "Invoice" |
| [02_relational_part1.md](02_relational_part1.md) | Relational model after part 1 (normalized) |
| [03_relational_part2.md](03_relational_part2.md) | After part 2: redundant columns D1, D2, D3 and their triggers |
| [04_relational_part3.md](04_relational_part3.md) | After part 3: TotalAmount, Incoterm removed, CustomerDetails + CustomerFull, partitioned Invoice |

Related: [explanations/](../explanations/README.md), [assignments/](../assignments/README.md).

## How to view Mermaid

- GitHub renders the `mermaid` code blocks directly in the browser.
- VS Code: install the extension `bierner.markdown-mermaid`, then open the Markdown preview (Ctrl+Shift+V).

## How to draw with Draw.io

1. Install the VS Code extension `hediet.vscode-drawio`.
2. Create a file ending in `.drawio.svg` in this folder (for example `05_my_diagram.drawio.svg`) and draw in the editor.
3. The file is a normal SVG: GitHub renders it, and it can be pasted into the Word report.

## Naming convention

`NN_topic.md` for Mermaid files (`01_document_<name>.md`, `02_relational_partN.md`), `NN_topic.drawio.svg` for Draw.io files. The number orders the files in the report: documents first, then the relational model by part.

## Export PNG for the report

- Mermaid CLI, one diagram per command (the input may be a Markdown file; one PNG is written per diagram):

  ```
  npx -p @mermaid-js/mermaid-cli mmdc -i 02_relational_part1.md -o 02_relational_part1.png
  ```
- Draw.io: File > Export as > PNG (or just paste the `.drawio.svg`).

## Adapting to your own model

1. Replace the entities and attributes in each diagram with those of your domain; column names must match your `queries/*.sql` exactly.
2. Keep one conceptual diagram per business document, showing only the entities that document touches.
3. Update the relational diagrams after every part; mark redundant columns with a comment, and list the trigger that maintains each one.
4. Use ASCII identifiers only (no diacritics or spaces) so Mermaid parses them.

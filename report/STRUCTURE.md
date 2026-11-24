# Report structure (BP3_projekat.docx)

Chapter map of the master report. Status: `done` (content in the report), `partial`,
`empty` (heading only). Update this file in the same commit as the report.

Current report version: **1.6** (24.11.2026)

## Chapters

| # | Chapter (as in the report) | Repo files | Status |
|---|---|---|---|
| 1 | OPIS PROJEKTA | `assignments/01_database_design.md` | |
| 1.1 | Opis podsistema za koji se projektuje baza podataka | - | done |
| 1.2 | Poslovna dokumenta koja se koriste u procesu (7 forms, figures 1-7) | - | done |
| 2 | PROJEKTOVANJE BAZE PODATAKA | `assignments/01_database_design.md`, `explanations/01_database_design.md` | |
| 2.1 | Model podataka (PMOV per document, figures 8-14) | `diagrams/01_document_*.md` | done |
| 2.2 | Relacioni model (29 relations) | `diagrams/02_relational_part1.md`, `queries/01_tables.sql`, `queries/02_data.sql` | done |
| 3 | DENORMALIZACIJA RELACIJA | `assignments/02_denormalization.md`, `explanations/02_denormalization.md` | |
| 3.1 | Narusavanje 2NF: D1 Normativ (NazivMaterijala, OznakaJM) | `queries/03_denormalization.sql`, `diagrams/03_relational_part2.md` | done |
| 3.2 | Narusavanje 3NF: D2 Racun (kupac, 3 levels), D3 StavkaRacuna.Iznos | `queries/03_denormalization.sql` | done |
| 4 | NAPREDNA PRETRAGA I TRIGERI | `explanations/05_normal_forms_and_triggers.md` | |
| 4.1 | Napredna pretraga | `queries/joins_examples.sql`, `queries/window_examples.sql` | empty |
| 4.2 | Realizacija proceduralne logike uz pomoc trigera (T1-T7, tests) | `queries/04_triggers.sql`, `queries/05_tests.sql` | done |
| 5 | OPTIMIZACIJA BAZE PODATAKA | `assignments/03_optimization.md`, `explanations/03_optimization.md`, `spec/01_*`, `spec/02_*` | |
| 5.1 | Definisanje i analiza indeksa | `queries/08_generate_data.sql`, `queries/09_indexes.sql` | empty |
| 5.2 | Horizontalno particionisanje | `queries/10_partitioning.sql`, `queries/11_test_partitioning.sql` | empty |
| 5.3 | Vertikalno particionisanje | `queries/10_partitioning.sql`, `queries/11_test_partitioning.sql` | empty |
| 5.4 | Primena drugih optimizacionih tehnika | `queries/06_logical_optimization.sql`, `queries/07_test_logical.sql` | empty |
| 6 | TEHNOLOGIJE ZA IMPLEMENTACIJU PROJEKTA | `SETUP.md`, `docker-compose.yml` | |
| 6.1 | SUBP koriscen za implementaciju baze podataka | - | empty |
| 6.2 | Programsko okruzenje za razvoj korisnickog interfejsa | - | empty |

## Labels used in the report

| Label | Meaning | Defined in |
|---|---|---|
| D1 | Normativ: NazivMaterijala, OznakaJM (2NF, pre-joining) | 3.1 |
| D2 | Racun: SifKupca, NazivKupca, PIBKupca (3NF, 3 levels, short-circuit key + pre-joining) | 3.2 |
| D3 | StavkaRacuna: Iznos (3NF, derived attribute) | 3.2 |
| T1-T3 | `trg_normativ_materijal`, `trg_materijal_normativ`, `trg_normativ_zabrana` (D1) | 4.2 |
| T4-T6 | `trg_racun_kupac`, `trg_nzi_kn`, `trg_kn_kupac` (D2) | 4.2 |
| T7 | `trg_stavkaracuna_iznos` (D3) | 4.2 |
| pkg | `pkg_denorm.g_kaskada` cascade flag | 4.2 |

## Known gaps between report and repo

- The repo SQL, diagrams and explanations still hold the template example (orders and
  invoicing). The report describes production per customer order (29 relations). Chapters
  2-4 must be ported into `queries/` and `diagrams/` before the repo matches the report.
- The report calls the test script `05_testiranje.sql`; the repo uses `queries/05_tests.sql`.
- The report flag is `pkg_denorm.g_kaskada`; `CLAUDE.md` names `pkg_denorm.g_cascade`.

## Version log

| Version | Date | Change |
|---|---|---|
| 1.0 | 30.10.2026 | Topic registration |
| 1.1 | 04.11.2026 | Data model (PMOV) and relational model |
| 1.2 | 04.11.2026 | Model changes after mentor review |
| 1.3 | 12.11.2026 | Denormalization and triggers |
| 1.4 | 16.11.2026 | Added D7 (product data on invoice item) |
| 1.5 | 17.11.2026 | Trigger identification and functional dependencies |
| 1.6 | 24.11.2026 | Denormalizations reduced to three (D1 2NF, D2 and D3 3NF) |

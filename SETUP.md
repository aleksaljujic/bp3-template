# Setup Guide

How to get a database running locally, run the scripts, and set up your editor.
You choose **one** database engine: Oracle 23ai Free, PostgreSQL 17 or MySQL 8.4.

> The example scripts in `queries/` are written in **Oracle SQL / PL/SQL** and `run_all.sh` supports
> Oracle only. PostgreSQL and MySQL containers are provided so you can port the project to them
> (see [Porting to PostgreSQL / MySQL](#porting-to-postgresql--mysql)).

## 1. Prerequisites

- **git**
- **Docker** with **Docker Compose v2** (`docker compose version`)
  - Linux: Docker Engine + the compose plugin; add your user to the `docker` group.
  - macOS: Docker Desktop (or Colima).
  - Windows: Docker Desktop with the **WSL2** backend. Run the repo and `run_all.sh` from inside a WSL2 distribution (Ubuntu) and keep the repo in the WSL file system, not under `/mnt/c`.
- About **4 GB of free RAM** for Oracle (PostgreSQL and MySQL need far less) and a few GB of disk.

## 2. Clone the repository

```bash
git clone <REPO_URL>
cd <REPO_FOLDER>
cp .env.example .env      # then edit .env if you want other passwords or ports
```

`.env` is git-ignored. All variables are documented in `.env.example`.

## 3. Choose ONE database engine

Start exactly one profile. Set `DB_ENGINE` in `.env` to the same value.

### Oracle Database 23ai Free

```bash
docker compose --profile oracle up -d
docker compose ps                      # wait for "healthy"
docker compose logs -f oracle-free     # look for "DATABASE IS READY TO USE!"
```

- First start: 1-3 minutes (the database is created); later starts are faster.
- Connect string: `app/app@//localhost:1521/FREEPDB1` (host `localhost`, port `1521`, service `FREEPDB1`).
- User and password: `APP_USER` / `APP_PASSWORD` from `.env` (default `app` / `app`). `SYS`/`SYSTEM` password: `ORACLE_PASSWORD`.
- CLI inside the container: `docker exec -it oracle-free sqlplus app/app@//localhost:1521/FREEPDB1`

### PostgreSQL 17

```bash
docker compose --profile postgres up -d
docker compose ps
docker compose logs -f postgres
```

- First start: a few seconds.
- Connect: host `localhost`, port `5432`, database `app`, user/password `app` / `app` (from `.env`).
  URL: `postgresql://app:app@localhost:5432/app`
- CLI: `docker exec -it postgres psql -U app -d app`

### MySQL 8.4

```bash
docker compose --profile mysql up -d
docker compose ps
docker compose logs -f mysql
```

- First start: 20-60 seconds.
- Connect: host `localhost` (use `127.0.0.1` in some clients), port `3306`, database `app`, user/password `app` / `app`.
- CLI: `docker exec -it mysql mysql -uapp -papp app`
- Root user: password `MYSQL_ROOT_PASSWORD`.

### Stop and reset

| Goal | Command |
|---|---|
| Stop, keep data | `docker compose --profile <engine> stop` |
| Remove container, keep data (named volume) | `docker compose --profile <engine> down` |
| Remove container **and data** (fresh database) | `docker compose --profile <engine> down -v` |

Without `--profile`, compose does nothing for these services.

## 4. Pulling images manually (optional)

Compose pulls on first start. To prepare in advance (for example on a slow connection):

```bash
docker pull gvenzl/oracle-free:slim     # Oracle, large: roughly 1.5 GB download, several GB on disk
docker pull postgres:17
docker pull mysql:8.4
```

## 5. Running the scripts

Oracle:

```bash
./run_all.sh                              # queries/00 .. 11, output in results/<script>.txt
./run_all.sh 05_tests                     # one script
CONTAINER=my-oracle ./run_all.sh          # other container name
```

If `DB_ENGINE=postgres` or `mysql`, `run_all.sh` prints a message and exits: the scripts are Oracle-specific.
Interactive alternative: open the files from `queries/` in your editor and run them against the connection.

## Porting to PostgreSQL / MySQL

Main differences between what the template uses (Oracle) and the other engines.

| Topic | Oracle (template) | PostgreSQL | MySQL 8.4 |
|---|---|---|---|
| Types | `VARCHAR2(n)`, `NUMBER(p,s)`, `DATE` (has time) | `VARCHAR(n)`, `NUMERIC(p,s)`, `DATE` / `TIMESTAMP` | `VARCHAR(n)`, `DECIMAL(p,s)`, `DATE` / `DATETIME` |
| Generated keys | `GENERATED ... AS IDENTITY` / sequences | `GENERATED ... AS IDENTITY` / `SERIAL` / sequences | `AUTO_INCREMENT` |
| Trigger syntax | `CREATE TRIGGER ... BEGIN ... END;` with `:NEW` / `:OLD` | trigger function (`RETURNS trigger`, `LANGUAGE plpgsql`) + `CREATE TRIGGER ... EXECUTE FUNCTION`; `NEW` / `OLD` (no colon) | `CREATE TRIGGER ... FOR EACH ROW BEGIN ... END`; `NEW` / `OLD`; no `UPDATE OF col` (test with `IF NEW.col <> OLD.col`); one trigger per timing and event unless `FOLLOWS`/`PRECEDES` |
| Compound trigger (T6) | `COMPOUND TRIGGER` with row and statement sections | statement-level `AFTER` trigger with transition tables (`REFERENCING NEW TABLE AS ...`) | no equivalent; recompute per row (and the trigger may not update the table it fires on), or use a stored procedure / application logic |
| Raise an error | `RAISE_APPLICATION_ERROR(-20001, 'msg')` | `RAISE EXCEPTION 'msg' USING ERRCODE = 'P0001';` | `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'msg';` |
| Flag variable (`pkg_denorm.g_cascade`) | package variable | custom setting: `SET LOCAL app.cascade = 'on'`, read with `current_setting('app.cascade', true)` | user variable `@cascade` (session scoped) |
| CHECK constraints | `ck_*` CHECK | same (`ALTER TABLE ... ADD CONSTRAINT ... CHECK`) | enforced since 8.0.16 |
| Dynamic SQL (P1) | `EXECUTE IMMEDIATE` | `EXECUTE` in plpgsql, `format('%L', ...)` / `%I` for quoting | `PREPARE` / `EXECUTE` in a stored procedure |
| Bitmap index | `CREATE BITMAP INDEX` | none; use a B-tree (bitmap scans are built on the fly at run time) | none; use a B-tree |
| Function-based index | `ON t(UPPER(name))` | expression index `ON t(upper(name))` | functional key part `ON t((UPPER(name)))`, MySQL 8.0.13+ |
| Horizontal partitioning | `INTERVAL` range, partitions auto-created, `MODIFY PARTITION BY ... ONLINE` | declarative `PARTITION BY RANGE`; create partitions yourself (or a default partition); converting needs a new table + copy | `PARTITION BY RANGE`; add partitions with `ALTER TABLE ... REORGANIZE/ADD PARTITION`; **partitioned tables cannot have foreign keys** (and the partition key must be in every unique key) |
| Vertical partitioning view + INSTEAD OF | `INSTEAD OF` triggers on the view | simple views are auto-updatable, otherwise `INSTEAD OF` triggers or rules | views over a join are not updatable and there are no `INSTEAD OF` triggers: use stored procedures |
| Query plans | `EXPLAIN PLAN FOR ...; SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY)` | `EXPLAIN (ANALYZE, BUFFERS) ...` | `EXPLAIN ANALYZE ...` |
| Statistics | `DBMS_STATS.GATHER_SCHEMA_STATS` | `ANALYZE` | `ANALYZE TABLE` |
| DDL and transactions | DDL commits implicitly | **transactional DDL** (can be rolled back) | DDL commits implicitly |
| Generating rows | `CONNECT BY LEVEL` | `generate_series(1, n)` | recursive CTE (`WITH RECURSIVE`) |
| Test scripts | SQL*Plus (`SET SERVEROUTPUT ON`, `/`) | `psql` (`\echo`, `\set ON_ERROR_STOP`) | `mysql` client (`DELIMITER //` for routines) |

Suggested approach: port `01`, `02`, then `03`-`05`, run them, and only then continue with part 3. Document each
difference you meet in `explanations/`; it is good material for the defense.

## 6. Editor extensions

### VS Code (recommended)

Open the repo folder; VS Code offers the recommended extensions from `.vscode/extensions.json`
("Install All"). Or install individually from the Extensions view (Ctrl+Shift+X) or the terminal:

| Extension | Id | Used for | Install command |
|---|---|---|---|
| Oracle SQL Developer Extension | `Oracle.sql-developer` | Oracle connections, run scripts, PL/SQL editing | `code --install-extension Oracle.sql-developer` |
| SQLTools | `mtxr.sqltools` | generic SQL client UI (PostgreSQL, MySQL, and others) | `code --install-extension mtxr.sqltools` |
| SQLTools PostgreSQL driver | `mtxr.sqltools-driver-pg` | SQLTools driver for PostgreSQL | `code --install-extension mtxr.sqltools-driver-pg` |
| SQLTools MySQL driver | `mtxr.sqltools-driver-mysql` | SQLTools driver for MySQL | `code --install-extension mtxr.sqltools-driver-mysql` |
| Docker | `ms-azuretools.vscode-docker` | see containers, logs, shell into them | `code --install-extension ms-azuretools.vscode-docker` |
| Markdown All in One | `yzhang.markdown-all-in-one` | Markdown shortcuts, TOC, preview | `code --install-extension yzhang.markdown-all-in-one` |
| Markdown Preview Mermaid Support | `bierner.markdown-mermaid` | Mermaid diagrams in the Markdown preview | `code --install-extension bierner.markdown-mermaid` |
| Draw.io Integration (optional) | `hediet.vscode-drawio` | ER and relational model diagrams (`*.drawio`, `*.drawio.svg`) | `code --install-extension hediet.vscode-drawio` |

Creating a connection (use the values from your `.env`):

- **Oracle SQL Developer extension**: open the Oracle icon in the sidebar, "Create Connection". Name: anything; Connection type: Basic; Hostname `localhost`; Port `1521`; **Service name `FREEPDB1`**; Username `app`; Password `app` (save it). Test, then connect. Open a `.sql` file and run it with the connection selected.
- **SQLTools, PostgreSQL**: SQLTools icon, "Add New Connection", PostgreSQL. Server `localhost`, Port `5432`, Database `app`, Username `app`, Password `app`.
- **SQLTools, MySQL**: same, choose MySQL. Server `localhost`, Port `3306`, Database `app`, Username `app`, Password `app`.
- **Docker extension**: nothing to configure; right-click the container for "View Logs" or "Attach Shell".

### Alternatives

Oracle SQL Developer (desktop), DBeaver (all engines), pgAdmin (PostgreSQL), MySQL Workbench (MySQL), DataGrip (JetBrains, paid).
Use the same host, port, service/database name and credentials as above.

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| `port is already allocated` | Another service uses 1521/5432/3306. Stop it or set `ORACLE_PORT` / `POSTGRES_PORT` / `MYSQL_PORT` in `.env` and reconnect on the new port. |
| Container stays `starting` / `unhealthy` | Oracle's first start is slow; wait 2-3 minutes and watch `docker compose logs -f oracle-free`. Check Docker has at least 4 GB RAM assigned (Docker Desktop settings). |
| `ORA-12514` listener does not know the service | Use service name `FREEPDB1` (not `XE`, not an SID) and the form `//host:1521/FREEPDB1`. The listener may still be starting. |
| `ORA-01017` invalid username/password | Use `app` / `app` (or your `APP_USER` / `APP_PASSWORD`). If you changed `.env` after the first start, the user already exists with the old password: `docker compose --profile oracle down -v` and start again. |
| PostgreSQL `password authentication failed` / MySQL `Access denied` | Same cause: credentials are applied only on first initialization of the volume. Reset with `down -v`, or use the values from the first start. For MySQL clients on the host, try `127.0.0.1` instead of `localhost`. |
| Apple Silicon (M1/M2/M3) with the Oracle image | Use a recent Docker Desktop; the image has an arm64 build. If it does not start, enable "Use Rosetta for x86/amd64 emulation" or use Colima with `--vm-type vz --vz-rosetta`, or choose PostgreSQL/MySQL. Expect slower starts. |
| `run_all.sh: bad interpreter` / `\r` errors on Windows | Windows line endings. Run `git config core.autocrlf input`, re-clone (or `git rm --cached -r . && git reset --hard`). The repo ships a `.gitattributes` forcing LF for `*.sh` and `*.sql`. Run it from WSL2. |
| `run_all.sh: Container 'oracle-free' is not running` | Start with `docker compose --profile oracle up -d`; check the name with `docker ps`; use `CONTAINER=<name>`. |
| `permission denied` on `./run_all.sh` | `chmod +x run_all.sh` |

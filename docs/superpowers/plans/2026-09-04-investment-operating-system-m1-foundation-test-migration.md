# Investment Operating System Milestone 1 — Foundation, Test Harness, and Migration Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Feature:** Investment Operating System Milestone 1 — Foundation, Test Harness, and Migration Baseline

**Goal:** Establish an isolated backend test harness, lock down existing behavior, and create a verified legacy Alembic baseline process without touching a deployment database blindly.

**Architecture:** All implementation commands run from the `backendtest` repository; this plan and its governing specification live in the sibling `stock-price-alert` repository. Tests use a temporary SQLite database and mocked network boundaries. The committed baseline represents the existing SQLAlchemy model schema, while any stamp or upgrade against an active database remains blocked until a deployment operator completes the documented inventory, backup, and drift gate.

**Tech Stack:** Python 3.12, Flask 2.3.3, Flask-SQLAlchemy 3.0.5, SQLAlchemy 2.0.x, Flask-Migrate 4.0.5, Alembic 1.16.x, Flask-JWT-Extended 4.5.3, Marshmallow 3.20.1, pytest 8.3.5, SQLite for isolated tests.

**Spec:** `../stock-price-alert/docs/superpowers/specs/2026-09-04-investment-operating-system-milestone-1-design.md`

## Global Constraints

- Run implementation and test commands from `backendtest`; do not add frontend application files.
- Preserve existing authentication, User, Ticker, Trade, Tag, TelegramVerification, Telegram, Kite, websocket, ticker-price, and trade-evaluation behavior and response shapes.
- Do not add columns to existing `user`, `ticker`, `trade`, `tag`, `trade_tags`, or `telegram_verification` tables.
- `BaseModel` remains the source of string UUID primary keys and UTC `created_at`; new mutable models declare their own `updated_at`.
- Tests must not read `kite/kite.json`, call Kite, call Google, call Telegram, connect to Elasticsearch, or use a deployment `DATABASE_URL`.
- Do not run `db.create_all()` during application startup; it is allowed only inside isolated test fixtures and schema-characterization helpers.
- Do not stamp or upgrade an active database until its dialect, backup, Alembic state, schema equivalence, and drift record have been verified by a deployment operator.
- The Milestone 1 migration must be additive and must leave every legacy table structurally unchanged.
- Do not implement research domain models, services, routes, seed data, or frontend behavior in this plan.

---

## Repository findings that constrain this plan

- `app.create_app(config_class=Config)` already supports dependency injection of a test configuration.
- `Config` loads `.env`, defaults to `sqlite:///trading_app.db`, and exposes no test subclass.
- `BaseModel` defines `id: String(36)` and timezone-aware `created_at`; it does not define `updated_at`.
- Legacy schemas are centralized in `app/utils/schemas.py`; legacy routes validate and commit directly.
- `admin_required` and `get_current_user` live in `app/utils/auth.py` and must be characterized before reuse.
- Flask-Migrate is initialized, but the repository has no `migrations/` directory or `alembic_version` history.
- The repository has no tests, pytest configuration, development requirements file, Dockerfile, Procfile, or CI workflow.
- `kite/kite.json` is tracked and contains configured credentials; tests must neither open nor mutate it.
- The available Codex runtime has Python 3.12 but does not currently have the backend requirements or pytest installed.

## Task 1: Isolated pytest harness

**Files:**
- Create: `requirements-dev.txt`
- Create: `pytest.ini`
- Create: `tests/__init__.py`
- Create: `tests/conftest.py`
- Create: `tests/test_app_factory.py`
- Modify: none

**Interfaces:**
- Consumes: `app.create_app(config_class=Config)`, `app.db`, and `config.Config`.
- Produces: pytest fixtures `app`, `client`, `user_factory`, `auth_headers`, `admin_user`, `free_user`, and `premium_user`; all later plans consume these names unchanged.

- [ ] **Step 1: Add the development dependency manifest and write the failing harness test**

  `requirements-dev.txt` must contain:

  ```text
  -r requirements.txt
  pytest==8.3.5
  ```

  `tests/test_app_factory.py` must assert:

  ```python
  def test_app_fixture_uses_isolated_configuration(app):
      assert app.config["TESTING"] is True
      assert app.config["ELASTICSEARCH_URL"] is None
      assert "test-" in app.config["SQLALCHEMY_DATABASE_URI"]
  ```

- [ ] **Step 2: Install test dependencies and confirm the fixture failure**

  Run: `python -m pip install -r requirements-dev.txt`

  Run: `python -m pytest tests/test_app_factory.py -q`

  Expected: collection fails because fixture `app` is not defined; no repository SQLite file or network request is created.

- [ ] **Step 3: Add the minimal isolated fixtures**

  In `tests/conftest.py`, define `TestingConfig`, set `TestingConfig.SQLALCHEMY_DATABASE_URI = f"sqlite:///{(tmp_path / f'test-{uuid.uuid4()}.db').as_posix()}"`, set `TESTING=True`, `JWT_SECRET_KEY="test-jwt-secret"`, and `ELASTICSEARCH_URL=None`, then call `create_app(TestingConfig)`. Within the app context, import `app.models`, call `db.create_all()`, yield the app, and finally call `db.session.remove()` and `db.drop_all()`.

  Define these exact helpers:

  ```python
  @pytest.fixture
  def user_factory(app):
      def create_user(*, email: str, is_admin: bool = False) -> User:
          user = User(name=email.split("@")[0], email=email, is_admin=is_admin)
          user.set_password("test-password")
          db.session.add(user)
          db.session.commit()
          return user
      return create_user

  @pytest.fixture
  def auth_headers(app):
      def make_headers(user: User) -> dict[str, str]:
          return {"Authorization": f"Bearer {create_access_token(identity=user.id)}"}
      return make_headers
  ```

  `admin_user`, `free_user`, and `premium_user` initially create legacy `User` rows only. Plan 2 replaces the premium fixture's marker with a persisted `UserEntitlement` after that model exists.

- [ ] **Step 4: Run the harness test and the empty suite**

  Run: `python -m pytest tests/test_app_factory.py -q`

  Expected: 1 passed; database files exist only under pytest temporary storage.

- [ ] **Step 5: Commit the harness**

  ```bash
  git add requirements-dev.txt pytest.ini tests/__init__.py tests/conftest.py tests/test_app_factory.py
  git commit -m "test: add isolated backend test harness"
  ```

## Task 2: Authentication, user, and ticker contract characterization

**Files:**
- Create: `tests/legacy/test_auth_contract.py`
- Create: `tests/legacy/test_user_contract.py`
- Create: `tests/legacy/test_ticker_contract.py`
- Modify: `tests/conftest.py`
- Tests: the three files above

**Interfaces:**
- Consumes: Task 1 fixtures and existing `/api/auth`, `/api/users`, and `/api/tickers` routes.
- Produces: executable regression contracts for status codes and JSON keys that Plan 5 must keep green.

- [ ] **Step 1: Write characterization tests using the exact current response shapes**

  Cover registration validation, login success/failure, refresh, `/api/auth/me`, self-versus-admin user access, ticker search, and missing JWT. Assert concrete keys such as `access_token`, `refresh_token`, `user`, `tickers`, `total`, `page`, and `per_page`; do not normalize legacy responses into the new research collection shape.

  Add a `ticker_factory(symbol="IKIO", instrument_token=1)` fixture that creates `Ticker(exchange="NSE", name="IKIO Technologies Limited", last_price=100.0)`.

- [ ] **Step 2: Run the characterization tests and record actual mismatches**

  Run: `python -m pytest tests/legacy/test_auth_contract.py tests/legacy/test_user_contract.py tests/legacy/test_ticker_contract.py -q`

  Expected: tests that accurately encode current behavior pass; any expectation that differs from current behavior fails and must be corrected to the observed response before proceeding. No application file is changed in this task.

- [ ] **Step 3: Complete fixtures without changing production behavior**

  Keep all setup in `tests/conftest.py`. Use Flask-JWT-Extended tokens created inside `app.app_context()`; do not add tier claims. Monkeypatch `app.utils.auth.verify_google_token` for Google-route tests so no external HTTP call occurs.

- [ ] **Step 4: Run the complete legacy contract group**

  Run: `python -m pytest tests/legacy/test_auth_contract.py tests/legacy/test_user_contract.py tests/legacy/test_ticker_contract.py -q`

  Expected: all tests pass with zero external calls and no changes to existing route or schema files.

- [ ] **Step 5: Commit the characterization suite**

  ```bash
  git add tests/conftest.py tests/legacy/test_auth_contract.py tests/legacy/test_user_contract.py tests/legacy/test_ticker_contract.py
  git commit -m "test: characterize auth user and ticker contracts"
  ```

## Task 3: Trade, tag, Telegram, and live-pipeline characterization

**Files:**
- Create: `tests/legacy/test_trade_tag_contract.py`
- Create: `tests/legacy/test_telegram_contract.py`
- Create: `tests/legacy/test_live_pipeline_boundaries.py`
- Modify: `tests/conftest.py`
- Tests: the three files above

**Interfaces:**
- Consumes: `Trade.check`, `Trade.update_etas`, `/api/trades`, `/api/tags`, `/api/telegram`, `TelegramService`, and `live/websocket.py`.
- Produces: regression guards for trade transitions, response fields, notification calls, ticker writes, and the absence of research imports in the live path.

- [ ] **Step 1: Write failing characterization tests around isolated helpers**

  Add `trade_factory` and `candle_factory` fixtures. Test current trade create/read/update/delete shapes, tag reuse by user, ENTRY/STOPLOSS/TARGET transitions, and ETA fields. In Telegram tests monkeypatch `requests.post`; in live-boundary tests parse `live/websocket.py` with `ast` and assert no import path begins with `app.services.research`, `app.services.document`, or `app.policies`.

- [ ] **Step 2: Run the new characterization group**

  Run: `python -m pytest tests/legacy/test_trade_tag_contract.py tests/legacy/test_telegram_contract.py tests/legacy/test_live_pipeline_boundaries.py -q`

  Expected: failures are limited to missing test fixtures or incorrectly recorded current behavior; no real Telegram or Kite request occurs.

- [ ] **Step 3: Complete deterministic test doubles**

  Provide a simple candle object with `high` and `low`; freeze test timestamps by asserting type and ordering rather than wall-clock equality. Patch `telegram_service.send_message` and `telegram_service.send_trade_alert` at their use sites. For websocket behavior, instantiate `TickerManager` only with `Kite`, timers, and network calls monkeypatched; verify `update_ticker_price()` changes only `Ticker.last_price` and `Ticker.last_updated` and `check_trades()` calls only legacy trade/notification paths.

- [ ] **Step 4: Run all legacy regression tests**

  Run: `python -m pytest tests/legacy -q`

  Expected: all legacy characterization tests pass; `kite/kite.json` has identical Git status before and after the run.

- [ ] **Step 5: Commit the live-boundary regression suite**

  ```bash
  git add tests/conftest.py tests/legacy/test_trade_tag_contract.py tests/legacy/test_telegram_contract.py tests/legacy/test_live_pipeline_boundaries.py
  git commit -m "test: lock legacy trading and notification behavior"
  ```

## Task 4: Read-only database inventory utility

**Files:**
- Create: `scripts/inspect_database_schema.py`
- Create: `tests/migrations/__init__.py`
- Create: `tests/migrations/test_schema_inventory.py`
- Modify: none

**Interfaces:**
- Consumes: a database URL named by a command-line environment-variable argument.
- Produces: `inspect_schema(database_url: str) -> dict[str, object]` and a CLI that emits redacted JSON containing dialect, tables, columns, primary keys, foreign keys, unique constraints, indexes, and Alembic version rows.

- [ ] **Step 1: Write the failing inventory test**

  Create a temporary SQLite database with one table and assert that `inspect_schema(url)` returns `dialect == "sqlite"`, the table metadata, and `alembic_version.present is False`. Assert the returned payload contains no URL, password, environment-variable value, or row data.

- [ ] **Step 2: Run the inventory test to verify the missing module failure**

  Run: `python -m pytest tests/migrations/test_schema_inventory.py -q`

  Expected: FAIL because `scripts.inspect_database_schema` does not exist.

- [ ] **Step 3: Implement the read-only inspector and CLI**

  Use `sqlalchemy.create_engine`, `sqlalchemy.inspect`, and read-only metadata calls. Define:

  ```python
  def inspect_schema(database_url: str) -> dict[str, object]:
      engine = sa.create_engine(database_url)
      inspector = sa.inspect(engine)
      tables = {
          name: inspect_table(inspector, name)
          for name in sorted(inspector.get_table_names())
      }
      return {
          "dialect": engine.dialect.name,
          "driver": engine.dialect.driver,
          "tables": tables,
          "alembic_version": inspect_alembic_version(engine, tables),
      }

  def main(argv: list[str] | None = None) -> int:
      args = parse_args(argv)
      database_url = os.environ[args.database_url_env]
      payload = inspect_schema(database_url)
      Path(args.output).write_text(
          json.dumps(payload, indent=2, sort_keys=True),
          encoding="utf-8",
      )
      return 0
  ```

  Define `inspect_table(inspector: Inspector, name: str) -> dict[str, object]`, `inspect_alembic_version(engine: Engine, tables: dict[str, object]) -> dict[str, object]`, and `parse_args(argv: list[str] | None) -> argparse.Namespace` in the same task. The concrete return keys are `dialect`, `driver`, `tables`, and `alembic_version`; each table contains sorted `columns`, `primary_key`, `foreign_keys`, `unique_constraints`, and `indexes`. The CLI accepts `--database-url-env` and `--output`, reads the named environment variable, writes UTF-8 JSON, and never prints the URL.

- [ ] **Step 4: Run the inspector tests**

  Run: `python -m pytest tests/migrations/test_schema_inventory.py -q`

  Expected: all tests pass and the generated JSON is deterministically sorted.

- [ ] **Step 5: Commit the inventory utility**

  ```bash
  git add scripts/inspect_database_schema.py tests/migrations/__init__.py tests/migrations/test_schema_inventory.py
  git commit -m "build: add read-only database schema inventory"
  ```

## Task 5: Legacy Alembic baseline and fresh-database proof

**Files:**
- Create: `migrations/README`
- Create: `migrations/alembic.ini`
- Create: `migrations/env.py`
- Create: `migrations/script.py.mako`
- Create: `migrations/versions/20260904_01_legacy_baseline.py`
- Create: `tests/migrations/helpers.py`
- Create: `tests/migrations/test_baseline_fresh.py`
- Modify: none

**Interfaces:**
- Consumes: current model metadata for `user`, `ticker`, `trade`, `tag`, `trade_tags`, and `telegram_verification`.
- Produces: Alembic revision `20260904_01`, plus `upgrade_database(database_url: str, revision: str) -> None` and `schema_snapshot(database_url: str, table_names: set[str]) -> dict` test helpers.

- [ ] **Step 1: Write the failing fresh-baseline migration test**

  Starting from an empty temporary SQLite file, call `upgrade_database(url, "20260904_01")`. Assert the exact legacy table set, columns, primary keys, foreign keys, named unique constraints, indexes, and SQLAlchemy enum/check representation match the model metadata snapshot. Assert no research or document table exists.

- [ ] **Step 2: Run the test to verify migration history is absent**

  Run: `python -m pytest tests/migrations/test_baseline_fresh.py -q`

  Expected: FAIL because the Alembic configuration and revision do not exist.

- [ ] **Step 3: Create and review the explicit baseline**

  Run: `flask --app main:app db init`

  Run: `flask --app main:app db revision --rev-id 20260904_01 -m "legacy schema baseline"`

  Implement `upgrade()` with ordered creation of `ticker`, `user`, `tag`, `telegram_verification`, `trade`, and `trade_tags`, copying exact current types, nullability, defaults, enum names, foreign keys, unique constraints, and indexes from the inspected models. Implement `downgrade()` in reverse dependency order. Do not include any Investment Operating System table.

- [ ] **Step 4: Run baseline and legacy regression tests**

  Run: `python -m pytest tests/migrations/test_baseline_fresh.py tests/legacy -q`

  Expected: all tests pass; upgrading an empty database to `20260904_01` yields the legacy schema and does not change legacy application behavior.

- [ ] **Step 5: Commit the reviewed baseline**

  ```bash
  git add migrations tests/migrations/helpers.py tests/migrations/test_baseline_fresh.py
  git commit -m "build: add legacy database migration baseline"
  ```

## Task 6: Existing-schema stamp rehearsal and additive safety gate

**Files:**
- Create: `tests/migrations/test_existing_schema_stamp.py`
- Create: `tests/migrations/test_legacy_schema_immutability.py`
- Create: `docs/deployment/investment-operating-system-m1-database-gate.md`
- Modify: `tests/migrations/helpers.py`
- Tests: the two files above

**Interfaces:**
- Consumes: revision `20260904_01`, `inspect_schema`, `schema_snapshot`, and the exact legacy table-name set.
- Produces: `create_legacy_schema_copy(database_url: str) -> None`, `stamp_database(database_url: str, revision: str) -> None`, and a release-blocking deployment evidence format consumed by Plan 5 Task 1.

- [ ] **Step 1: Write failing stamp and immutability tests**

  Build an existing-schema copy by cloning only the six model tables plus `trade_tags` into a fresh `MetaData`, create them without Alembic, stamp `20260904_01`, and assert `alembic_version.version_num == "20260904_01"`. Snapshot every legacy table before and after the stamp and assert equality except for the new `alembic_version` table.

- [ ] **Step 2: Run the tests to verify the missing helper failure**

  Run: `python -m pytest tests/migrations/test_existing_schema_stamp.py tests/migrations/test_legacy_schema_immutability.py -q`

  Expected: FAIL because the existing-schema-copy and stamp helpers are undefined.

- [ ] **Step 3: Implement the helpers and deployment gate document**

  `docs/deployment/investment-operating-system-m1-database-gate.md` is a runbook, not fabricated evidence. It must define the required evidence for each active environment: environment name; dialect and driver; secured backup identifier and restore-check result; current `alembic_version` rows; path to redacted inventory JSON; model-versus-schema comparison result; every drift item and approved disposition; reviewer name; review timestamp; and explicit `BASELINE_EQUIVALENT=true` approval. It must state that signed evidence belongs in the controlled deployment record and that missing evidence blocks stamp, upgrade, and Plan 5 Task 1.

  The deployment operator runs the read-only inventory with:

  ```powershell
  python scripts/inspect_database_schema.py --database-url-env DATABASE_URL --output "$env:IOS_M1_AUDIT_DIR/schema-inventory.json"
  ```

  The operator obtains a backup with the active database platform's approved backup procedure; this command cannot be specified until the inventory identifies the dialect and hosting platform. The operator must record the exact backup and restore-verification command in the gate document before approval.

- [ ] **Step 4: Run all foundation tests**

  Run: `python -m pytest tests/test_app_factory.py tests/legacy tests/migrations -q`

  Expected: all repository-safe tests pass. No command in this task connects to an active database.

- [ ] **Step 5: Commit the stamp rehearsal and gate**

  ```bash
  git add tests/migrations/helpers.py tests/migrations/test_existing_schema_stamp.py tests/migrations/test_legacy_schema_immutability.py docs/deployment/investment-operating-system-m1-database-gate.md
  git commit -m "test: gate migration baseline against schema drift"
  ```

## Completion gates

**Repository gate for Plans 2–4:** Tasks 1–6 pass locally; revision `20260904_01` creates only the legacy schema; legacy contract tests are green; no active database has been contacted.

**Human/deployment gate for Plan 5 Task 1 and every real stamp/upgrade:** Each active database has a verified backup, redacted inventory, Alembic-history inspection, schema-versus-model comparison, resolved drift record, named reviewer, and `BASELINE_EQUIVALENT=true`. If this evidence is unavailable, domain and service development may continue, but no additive migration is generated from an active database and no active database is stamped or upgraded.

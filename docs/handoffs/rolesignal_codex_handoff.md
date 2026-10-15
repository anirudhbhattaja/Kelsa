# RoleSignal — Complete Product & Engineering Handoff for Codex

**Document type:** Product requirements + system design + implementation contract  
**Project name:** RoleSignal  
**Primary goal:** Build a genuinely useful, locally hosted personal career-discovery and application-tracking system, with a production-style Go backend and meaningful use of PostgreSQL, RabbitMQ, concurrency, distributed processing, Docker, testing, and observability.  
**Target build window:** Approximately 4 weeks / 56 hours for the first usable version.  
**Status:** Source of truth for product scope and implementation decisions.  

---

## 0. Instructions to Codex

Read this document fully before making code changes. Treat it as the current source of truth unless a decision is explicitly marked `TBD` or `MVP validation required`.

### Working rules

1. **Inspect the current repository before changing it.** Preserve any existing work. If this is a blank repository, initialize the structure described below.
2. Implement in small, verifiable milestones. Do not attempt to generate the entire system in one massive change.
3. At the start of each milestone, state the implementation plan and list the files likely to change. At the end, summarize what changed, explain important design choices, and report the exact tests/commands run and their outcomes.
4. Run formatting, unit tests, integration tests relevant to the milestone, and static checks before declaring a milestone complete. Do not claim a test passed unless it was actually run and passed.
5. Prefer simple, idiomatic Go over unnecessary abstraction. Do not create interfaces or packages without a clear reason.
6. Keep business logic out of Gin handlers. Use a clear separation between HTTP handlers, application/services, domain models, source connectors, persistence, and worker/messaging code.
7. Do not add an LLM, embeddings, vector database, Redis, Kubernetes, or another broker unless a separately approved requirement demonstrates real value. They are not part of the MVP.
8. Do not use AI to infer facts and present them as verified. Missing salary, city, experience, remote-work status, or posting dates must remain unknown unless present in source data or clearly labelled as inferred.
9. Do not implement unauthorized scraping, login automation, CAPTCHA bypass, session-cookie extraction, or automated application submission for LinkedIn, Naukri, or other restricted sites. Never ask the user for those account passwords. Use supported public interfaces and manual capture/import.
10. Never commit API keys, credentials, local databases, personal application notes, or `.env` files. Provide `.env.example` with placeholders only.
11. Do not silently broaden scope. The MVP must be useful, locally runnable, testable, and finishable within the stated time budget.
12. If an external API key is missing or an external provider is unavailable, the application must still start. The relevant source should show as unconfigured/disabled, and fixture-based tests must continue to work.
13. Do not fabricate source board identifiers, job records, metrics, coverage counts, or test results. Sample data must be explicitly labelled as demo/fixture data.
14. Keep the implementation friendly to a developer learning Go. Explain non-obvious code and design trade-offs in the milestone summary rather than dumping unexplained code.

### Required implementation order

- Milestone 0: Repository inspection, source/API feasibility spike, and implementation plan.
- Milestone 1: Go service skeleton, configuration, health endpoints, Docker Compose, PostgreSQL migrations.
- Milestone 2: Domain model, source connector interface, one working connector, ingestion/upsert, list/search API.
- Milestone 3: RabbitMQ, transactional outbox, synchronization-task lifecycle, worker, retries, and idempotency.
- Milestone 4: Additional source connectors and manual listing capture, saved jobs, application tracking.
- Milestone 5: Analytics, minimal local UI, observability, failure tests, docs and release polish.

If a milestone is too large, divide it into smaller milestones without changing the requirements.

---

# 1. Product Vision

## 1.1 What RoleSignal is

RoleSignal is a local-first, personal career-discovery and application-tracking tool. It collects job openings from configured sources that provide permitted/public listing access, normalizes them into one database, filters and ranks the listings against the user's preferences, tracks application progress, and reports how fresh and reliable each source is.

The user should be able to run RoleSignal on their own computer, open a local dashboard, search relevant positions, open the original employer/application URL, save opportunities, and track the status of applications without maintaining several spreadsheets and repeatedly checking the same company career pages.

The initial target profile is an early-career software engineer interested in:

- Go/backend engineering
- General software engineering
- AI engineering and AI infrastructure
- Relevant entry-level roles requiring approximately 0–2 years of experience
- Positions in Bengaluru and other selected Indian cities, plus remote roles when the source explicitly describes them as remote

These preferences must be configurable, not hard-coded in the business logic.

## 1.2 The user problem

The user searches across many career pages and job platforms. Listings are duplicated across sources, location and experience data are inconsistent, some listings are stale, and applications are tracked separately. Restricted sites such as LinkedIn and Naukri cannot safely be assumed to allow unattended scraping.

RoleSignal reduces this manual effort without claiming to index the whole internet.

## 1.3 Product value

The initial product is successful if the user can:

1. Discover useful new listings from a practical set of supported sources.
2. Filter by role/keywords, city, remote/hybrid/on-site, experience, source, and freshness where data is available.
3. Tell which source supplied a listing and when it was last observed.
4. Avoid repeated listings from repeated synchronizations.
5. Save opportunities and manage application status.
6. See when source synchronization is failing rather than mistaking missing data for an empty market.
7. Review personal search/application metrics based on records the user actually entered.

The system must clearly disclose source coverage limits. It is not a full replacement for LinkedIn, Naukri, company ATS systems, or a universal scraper.

---

# 2. Product Boundaries

## 2.1 In scope for the MVP

- Local-only personal instance; one user, no multi-tenant SaaS features.
- Go REST API implemented with Gin.
- PostgreSQL as the primary relational database.
- RabbitMQ as a durable asynchronous task broker.
- Independent API and worker processes from the same Go codebase.
- Transactional outbox to bridge PostgreSQL transactions and RabbitMQ publishing.
- At-least-once message delivery with idempotent processing.
- Public job listing sources with documented interfaces, configured on a per-provider or per-company basis.
- At least one broad job API connector if API access/coverage is validated, plus company-specific public ATS connectors as supported.
- Manual listing capture for jobs discovered manually on platforms such as LinkedIn or Naukri.
- Normalization, source-based deduplication, filtering, basic deterministic relevance ranking, pagination, and source freshness tracking.
- Saved jobs and a personal application pipeline.
- Basic listing and personal application analytics.
- Minimal local UI so the product is practically usable. Keep UI intentionally simple; the backend/API is the primary engineering focus.
- Docker Compose-based local deployment.
- Unit, integration, end-to-end, failure-recovery, race-detection, and basic performance tests.
- Structured logs, health/readiness endpoints, and basic application metrics.

## 2.2 Explicitly out of scope for the MVP

- Automated login or scraping of LinkedIn, Naukri, or other restricted websites.
- CAPTCHA bypass, browser fingerprint evasion, session-cookie collection, or account-password storage.
- Universal automatic application submission. RoleSignal should open the original application page; the user submits applications themselves.
- Kubernetes, multi-region deployment, cloud hosting, microservice-per-domain architecture, or a public multi-user service.
- LLM calls, embedding generation, vector search, or a vector database as a requirement.
- Automated resume rewriting or fabricated job-fit claims.
- Claims that the platform has complete job-market coverage.
- Guessing that a role is closed solely because a listing wasn't returned by a partial search query.
- Complex recommendation ML, advanced salary prediction, or arbitrary crawling of user-provided URLs.

## 2.3 Potential future enhancements (not MVP commitments)

- Optional embedding-based semantic ranking after a deterministic baseline is measured.
- Resume-to-description match explanations with evidence snippets, clearly labelled as estimates.
- Optional email alerts or local notifications.
- Import of job-alert emails using an explicit, user-approved local mailbox integration.
- Additional supported ATS connectors.
- Export to CSV/JSON and richer personal analytics.
- gRPC only if a future component has a concrete RPC/streaming need. The MVP uses REST.

---

# 3. Source Strategy and Feasibility Requirements

**Source feasibility is a gating activity, not an assumption.** The broadness and quality of RoleSignal's results depend on the actual interfaces available to the user.

## 3.1 Candidate sources

### A. Adzuna API — candidate broad aggregator

- Use the documented job search API if the user obtains an API ID/key and the API supports the intended country, query, and usage pattern.
- Read credentials from environment variables `ADZUNA_APP_ID` and `ADZUNA_APP_KEY`.
- Do not hard-code credentials or commit them.
- Verify India coverage, quota, result limits, fields, terms, and attribution requirements during Milestone 0.
- If access or coverage is not adequate, leave the connector disabled and document the blocker; do not fake successful ingestion.

Official documentation: https://developer.adzuna.com/activedocs

### B. Greenhouse public job boards — company-specific listings

- Public job-board GET operations can provide published job data for a known board token.
- A company board token is needed per employer. Do not assume Greenhouse offers global discovery of all employers.
- Store the board token as non-secret source configuration when appropriate; never mix it with API credentials for application submission.

Official documentation: https://docs.greenhouse.io/job-board.html

### C. Lever Postings API — company-specific listings

- Fetch published postings for a configured Lever site/board.
- Board/site identifier is required.
- Treat listing reads and candidate application submission as separate capabilities. This project only reads public listings.

Official documentation: https://github.com/lever/postings-api

### D. Ashby Public Job Postings API — company-specific listings

- Fetch currently published job postings for a configured Ashby job-board name.
- Confirm available fields, location data, optional compensation fields, and limits before depending on them.

Official documentation: https://developers.ashbyhq.com/docs/public-job-posting-api

### E. Other providers

Additional connectors can be added after confirming their public interface, permitted use, access requirements, and data fields. Do not scrape an arbitrary career page merely because it is visible in a browser.

### F. Manual capture for LinkedIn, Naukri, and other manually discovered roles

- Allow the user to create a listing record by entering the title, company, original URL, location, and optional description/notes.
- It is acceptable to store the URL and user-entered fields. Do not automatically fetch arbitrary submitted URLs in the MVP.
- Clearly mark such records as manually added; source freshness cannot be guaranteed unless the record is checked through an authorized integration.
- Do not store LinkedIn or Naukri passwords, cookies, browser profiles, or login tokens.

## 3.2 Connector interface and capability model

All source connectors should implement a common internal interface, but the interface must account for provider differences. A conceptual interface is:

```go
type JobSource interface {
    Name() string
    ValidateConfig(ctx context.Context, cfg SourceConfig) error
    FetchPage(ctx context.Context, cfg SourceConfig, cursor string) (FetchPageResult, error)
}
```

`FetchPageResult` should contain normalized-or-raw listing candidates, the next cursor/page token, and source response metadata. Implementations may use provider-specific page numbers/cursors internally. Do not assume every source provides the same pagination or a complete snapshot.

Each source must declare or encode at least:

- Connector kind/provider.
- Company/board identifier if applicable.
- Query or filter configuration if applicable.
- Whether an enumeration is a complete company-board snapshot or a partial search result.
- Credential/configuration status without exposing secret values.
- Polling interval and last successful sync information.

Secrets belong in environment variables, not normal source configuration JSON. For the MVP, do not build a general-purpose secrets vault.

## 3.3 Source sync semantics

Different sources have different coverage semantics:

- A complete company-board response may allow marking previously seen records as absent from the latest successful snapshot, subject to safe confirmation rules.
- A paginated or query-limited aggregator search cannot treat every unreturned record as closed.
- A failed request provides no evidence that a job closed.
- A job's last-seen timestamp only proves that the source returned it at that time; it does not prove that its application link still works.

Use a cautious local status model: `open`, `stale`, `closed`, and `unknown`. Only mark `closed` when there is adequate explicit evidence under the connector's documented semantics. Otherwise show `stale` or `unknown`.

## 3.4 Feasibility spike acceptance criteria

Before building the full architecture:

- [ ] Verify at least one real source response using a supported interface.
- [ ] Confirm the exact fields available for title, employer, URL, location, dates, compensation, and description.
- [ ] Verify pagination, timeouts, rate limits, and any attribution/terms requirements.
- [ ] Validate that credentials are optional for local startup and handled securely when required.
- [ ] Record which source is the initial broad source and which configured ATS boards will be supported.
- [ ] Do not state a guaranteed number of jobs until the actual query results have been measured.

---

# 4. Functional Requirements

Requirements use identifiers so implementation and tests can refer to them.

## FR-01: Source registry

The user can list configured sources, see provider type and company/board, enable/disable them, inspect sync status, and request a manual sync. Source management must not expose secret material.

**Acceptance criteria:**
- `GET /api/v1/sources` returns source metadata and configuration status without credentials.
- Disabled sources are not picked up by scheduled sync.
- A manual sync request creates a durable task or returns a clear conflict if one is already active for that source.

## FR-02: Source synchronization

A configured source can be fetched asynchronously. Network calls must have timeouts and bounded response/pagination behavior. One failed source must not stop other sources.

**Acceptance criteria:**
- Sync request returns promptly with a task/run identifier.
- A worker fetches, normalizes, persists, and records the result.
- Each sync records fetched, inserted, updated, skipped, and error counts where measurable.
- Errors are visible through source/sync-run APIs and logs.

## FR-03: Listing normalization

Convert provider-specific listings to a shared data model. Preserve the original URL and source identity. Keep raw provider metadata only when useful and bounded.

**Acceptance criteria:**
- Fields missing from a provider stay null/unknown.
- Salary currency and period are explicit when available.
- Original location text is preserved alongside normalized location fields.
- Inferred fields (such as experience parsed from a description) are marked as inferred and never presented as source-verified facts.

## FR-04: Source-level deduplication and upsert

Repeated syncs of the same external listing must update the existing record instead of creating duplicates.

**Acceptance criteria:**
- Unique constraint on `(source_id, external_id)` for external source rows.
- Upsert operations are concurrency-safe.
- Repeated ingestion of the same fixture does not increase listing count.
- Cross-source potential duplicates may be flagged for review, but must not be destructively merged based only on a weak title/company/location match.

## FR-05: Search, filter, sort, and paginate listings

Support filters for free-text query, company, source, city, country, work mode, employment type, min/max experience, salary range where provided, first-seen/posted recency, saved status, and application status where meaningful.

**Acceptance criteria:**
- Unsupported/unknown fields do not silently match as verified data.
- Sorting is deterministic (include a stable secondary sort key).
- Pagination has a sensible default and maximum page size.
- SQL uses parameterized queries; never concatenate filter values into SQL strings.
- Empty results and malformed filters have consistent API behavior.

## FR-06: Location normalization

Normalize common spelling variants (for example, Bengaluru/Bangalore) while preserving the original text. Support city, region/state, country code, work mode, and an unknown state.

**Acceptance criteria:**
- Normalization mappings are deterministic and covered by tests.
- The service does not infer a city from ambiguous strings without marking uncertainty.
- Remote, hybrid, and on-site are distinct from city values.

## FR-07: Experience and skill metadata

Store source-provided experience/seniority when available. Simple parsing rules may extract likely experience ranges from descriptions, but extracted values must have a provenance flag such as `source`, `inferred`, or `unknown`.

Do not require an LLM for this. A deterministic rules-based baseline is sufficient for the MVP.

## FR-08: Save and manage listings

The user can save/unsave jobs and add personal notes.

**Acceptance criteria:**
- Saving the same listing twice is idempotent.
- Saved state and notes persist across restarts.
- The UI links to the original application page rather than attempting to submit an application.

## FR-09: Application tracking

The user can record and update application progress.

Suggested states: `applied`, `recruiter_screen`, `assessment`, `interview`, `offer`, `rejected`, `withdrawn`.

Store applied date, status history if implemented, notes, optional resume-version label, and next action/date. Do not assume an application was submitted merely because a user opened the application URL.

## FR-10: Manual listing capture

The user can create a manually captured listing by entering at minimum title, company, and application URL, with optional location, description, notes, and discovery source.

Do not fetch arbitrary manual URLs in the MVP. Validate URL format and allowed schemes; default to `https` and allow `http` only if explicitly required.

## FR-11: Source health and synchronization history

Show last attempt, last success, success/failure, duration, counts, and latest error summary for each source. Distinguish a failed sync from a successful sync returning zero listings.

## FR-12: Analytics

Provide truthful metrics based on stored observations and user-entered records:

- New listings first seen per day/week.
- Listings by city, work mode, company, source, and role/skill keyword when fields are available.
- Salary distributions only for postings with compatible, source-provided compensation.
- Saved/applied/interview/offer counts and conversion ratios based on recorded application statuses.
- Source sync success rate, failure counts, average/p95 duration if instrumented, last-success age, retry count, and queue backlog/oldest task age.

Do not claim market-wide job counts, applicant counts, or offer probabilities from the partial source set.

## FR-13: Local dashboard

Provide a basic responsive dashboard for listing search/filter, source health, saved jobs, application tracking, and a small analytics overview. It should work without a separate frontend build pipeline if feasible; simple server-served HTML/CSS/JavaScript or Go templates are preferred for MVP.

The UI is local-only and must make the source URL, freshness, and unknown/inferred fields visible.

## FR-14: Health and observability endpoints

Provide liveness, readiness, and metrics endpoints. Readiness should reflect required dependencies such as PostgreSQL and RabbitMQ; liveness should indicate whether the process is alive without incorrectly restarting merely because one upstream job source is down.

---

# 5. Non-Functional Requirements

All numeric targets are initial engineering targets to verify and revise with measurements, not performance claims.

## NFR-01: Local operation

The MVP must run on a developer's machine using Docker Compose. Host ports should bind to `127.0.0.1` by default. Do not expose the service or database to the public internet.

## NFR-02: Durability

When the API acknowledges a synchronization request as queued, the task and outbox event must already be committed in PostgreSQL. A process restart must not lose that request.

## NFR-03: Delivery semantics

Design for at-least-once delivery and idempotent processing, not exactly-once delivery. Duplicates can occur after publisher/worker crashes and must be safe to process.

## NFR-04: Isolation and concurrency

Multiple worker replicas must safely process independent tasks without concurrently mutating the same task as if each were the sole owner. Use database constraints/conditional updates and idempotent upserts as a correctness backstop.

## NFR-05: Responsiveness

Search should feel responsive for a local dataset. Initial target: p95 below 200 ms for common filtered search at 10,000 rows on the documented test machine. Measure with repeatable test data; document results and environment.

## NFR-06: Bounded resource use

External calls have deadlines. Pagination, body sizes, concurrency, and retry counts are bounded. Do not hold unbounded response bodies or unlimited job queues in memory.

## NFR-07: Maintainability

New supported source connectors should be addable without changing unrelated search/application business logic. Use a small common connector interface and provider-specific implementation/configuration.

## NFR-08: Observability

Failures should be diagnosable from structured logs, source sync history, task state, and metrics. Never log API keys, tokens, personal notes, or full sensitive payloads unnecessarily.

## NFR-09: Security

Secrets must be provided through environment variables or a local ignored `.env`; validate inputs and request limits. Default to localhost. Avoid arbitrary outbound fetches of user-supplied URLs. Manual URLs are stored and displayed, not fetched by the server.

## NFR-10: Reproducibility

A fresh checkout with Docker installed must have documented steps to start dependencies, apply migrations, run tests, and launch the application.

---

# 6. Proposed Technology Stack

Required:

- Language: Go (use the installed stable version and record it in README/CI).
- HTTP router: Gin.
- Database: PostgreSQL.
- Database driver: `pgx` (use `pgxpool` or a documented equivalent consistently).
- Migrations: Goose or another simple, actively maintained SQL migration tool; pick one and use it consistently.
- Queue: RabbitMQ using the official-team-maintained Go AMQP 0-9-1 client, `github.com/rabbitmq/amqp091-go`.
- Deployment: Docker + Docker Compose.
- Logging: `log/slog` structured JSON logs.
- Metrics: Prometheus client library or a small set of clearly documented metrics.
- API docs: OpenAPI 3.x, generated/maintained as a checked-in specification.
- Tests: Go `testing`, `httptest`, PostgreSQL integration tests, deterministic fake source connectors, and `go test -race ./...`.

Avoid adding a large framework ecosystem. Use a small number of well-supported dependencies and explain new dependencies in the milestone summary.

Reference documentation:

- Gin: https://gin-gonic.com/docs/
- Go database practices: https://go.dev/doc/database/
- PostgreSQL: https://www.postgresql.org/docs/
- RabbitMQ confirms/acks: https://www.rabbitmq.com/docs/confirms
- RabbitMQ reliability: https://www.rabbitmq.com/docs/reliability
- Go AMQP client: https://github.com/rabbitmq/amqp091-go
- Adzuna: https://developer.adzuna.com/activedocs
- Greenhouse Job Board API: https://docs.greenhouse.io/job-board.html
- Lever Postings API: https://github.com/lever/postings-api
- Ashby Public Job Postings API: https://developers.ashbyhq.com/docs/public-job-posting-api

---

# 7. High-Level Architecture (HLD)

## 7.1 Components

### API service (`cmd/api`)

- Gin HTTP server.
- Request validation and API error responses.
- Query/search and application-management endpoints.
- Source registry management and manual sync requests.
- Writes synchronization task and outbox event atomically.
- Does not perform long-running external source fetches inline.

### Worker service (`cmd/worker`)

One binary/process can run the following loops, with clean separation internally:

- Outbox publisher: finds due unpublished outbox records and publishes messages with publisher confirms.
- Scheduler: finds enabled sources due for refresh and creates tasks transactionally.
- RabbitMQ consumers: process sync messages, call connectors, normalize results, and write data.
- Retry scheduler: dispatches due retries or uses `available_at` on outbox events so retry dispatch can be durable.

Running more than one worker container must be supported. Database locks/conditional state changes ensure that scheduler/publisher/consumer instances do not corrupt the same record. Initially, one worker container is acceptable for the default local start; the same service must be able to scale to multiple replicas.

### PostgreSQL

Stores source configurations, job listings, saved jobs, applications, sync tasks/runs, outbox events, and optional listing observations/status history.

### RabbitMQ

Transports asynchronous sync-task messages. It is not the source of truth for job state; PostgreSQL is the source of truth.

### Source connectors

Each supported provider has a connector implementation. Providers are independently configured, timed out, rate-limited, and monitored.

### Local UI

A thin UI served by the API or from local assets. It calls the REST API and does not contain business logic that differs from the backend.

## 7.2 Primary data flow: request a source synchronization

1. User asks for a source sync through `POST /api/v1/sources/{id}/sync`.
2. API validates that the source exists, is supported, and is configured.
3. In one PostgreSQL transaction, create a sync task/run and its outbox message.
4. Commit; API returns `202 Accepted` with task/run ID.
5. Outbox publisher claims due events using a short transaction/lease strategy, publishes a persistent message to a durable queue, waits for publisher confirmation, then marks the event published.
6. If the publisher crashes after RabbitMQ accepted the message but before marking the event published, it may publish again. This is expected; the consumer must be idempotent.
7. A worker receives the message with manual acknowledgements. It conditionally claims the task in PostgreSQL and processes the source.
8. Worker fetches pages with timeouts and bounded pagination, normalizes records, and upserts them in batches/transactions.
9. Worker records sync counts and terminal success/failure state in PostgreSQL.
10. Worker acknowledges the RabbitMQ message only after the durable task outcome or retry schedule is committed.
11. Transient provider errors create a scheduled retry with a bounded backoff; permanent configuration/authentication errors become a visible terminal failure. One source's failure must not block other work.

## 7.3 Architecture principles

- PostgreSQL is authoritative for application and task state.
- RabbitMQ is transport, not a substitute for durable database records.
- At-least-once delivery is expected; every task/message path must be idempotent.
- Never acknowledge a valid message before the resulting state/retry is durably recorded.
- Never rely solely on a RabbitMQ queue to explain what happened to a task; retain task/run history in PostgreSQL.
- Never mark a listing closed merely because one partial query did not return it.
- Do not introduce microservices beyond API and worker processes from one codebase.

---

# 8. Database Design (Initial Logical Model)

Codex should implement migrations for the agreed model and document any justified simplification. Use UUID primary keys unless a clear reason supports another type. Use UTC timestamps (`timestamptz`) in PostgreSQL and display them in local time in the UI.

## 8.1 `sources`

Suggested fields:

- `id UUID PRIMARY KEY`
- `provider_type TEXT NOT NULL` — allowed values include `adzuna`, `greenhouse`, `lever`, `ashby`, `manual` (extend deliberately)
- `display_name TEXT NOT NULL`
- `company_name TEXT NULL` — required for company-specific boards where appropriate
- `board_identifier TEXT NULL`
- `config JSONB NOT NULL DEFAULT '{}'`
- `enabled BOOLEAN NOT NULL DEFAULT TRUE`
- `sync_interval_seconds INTEGER NOT NULL`
- `last_attempt_at TIMESTAMPTZ NULL`
- `last_success_at TIMESTAMPTZ NULL`
- `last_status TEXT NOT NULL DEFAULT 'never_synced'`
- `created_at`, `updated_at TIMESTAMPTZ NOT NULL`

Do not store credentials/secrets in `config`. Provider secrets must be resolved from environment variables or documented local configuration, not returned by the API.

## 8.2 `job_listings`

Suggested fields:

- `id UUID PRIMARY KEY`
- `source_id UUID NULL REFERENCES sources(id)` — nullable only if manual listings use a distinct representation; prefer a `manual` source row to keep this non-null.
- `external_id TEXT NOT NULL` for provider listings; use a generated stable local ID for manual records.
- `source_url TEXT NULL`
- `apply_url TEXT NOT NULL`
- `title TEXT NOT NULL`
- `company_name TEXT NOT NULL`
- `description TEXT NULL`
- `location_raw TEXT NULL`
- `city TEXT NULL`
- `region TEXT NULL`
- `country_code TEXT NULL`
- `work_mode TEXT NULL` — `remote`, `hybrid`, `on_site`, `unknown`
- `employment_type TEXT NULL`
- `min_experience_years NUMERIC NULL`
- `max_experience_years NUMERIC NULL`
- `experience_provenance TEXT NOT NULL DEFAULT 'unknown'` — `source`, `inferred`, `unknown`
- `salary_min NUMERIC NULL`
- `salary_max NUMERIC NULL`
- `salary_currency TEXT NULL`
- `salary_period TEXT NULL` — `hour`, `month`, `year`, `unknown`
- `compensation_provenance TEXT NOT NULL DEFAULT 'unknown'`
- `posted_at TIMESTAMPTZ NULL`
- `first_seen_at TIMESTAMPTZ NOT NULL`
- `last_seen_at TIMESTAMPTZ NOT NULL`
- `last_verified_at TIMESTAMPTZ NULL`
- `listing_status TEXT NOT NULL DEFAULT 'unknown'` — `open`, `stale`, `closed`, `unknown`
- `description_hash TEXT NULL`
- `raw_metadata JSONB NOT NULL DEFAULT '{}'` with payload size controls
- `created_at`, `updated_at TIMESTAMPTZ NOT NULL`

Constraints/indexes:

- Unique `(source_id, external_id)` for records with real external IDs. If manual IDs are generated, the same unique constraint remains usable.
- Indexes based on measured query patterns, initially including `(city, first_seen_at DESC)`, `(company_name)`, `(listing_status, last_seen_at DESC)`, and any practical full-text/search expression needed.
- Do not add every conceivable index. Check query plans and index only useful access paths.

Source-level dedupe is mandatory. Cross-source matching may calculate a normalized fingerprint for suggestions/analytics, but must not automatically collapse two distinct openings based only on title and company similarity.

## 8.3 `saved_jobs`

- `id UUID PRIMARY KEY`
- `job_listing_id UUID NOT NULL REFERENCES job_listings(id)`
- `saved_at TIMESTAMPTZ NOT NULL`
- `notes TEXT NULL`
- Unique constraint on `job_listing_id` for this single-user local product.

## 8.4 `applications`

- `id UUID PRIMARY KEY`
- `job_listing_id UUID NOT NULL REFERENCES job_listings(id)`
- `status TEXT NOT NULL` with allowed values `applied`, `recruiter_screen`, `assessment`, `interview`, `offer`, `rejected`, `withdrawn`
- `applied_at TIMESTAMPTZ NULL`
- `updated_at TIMESTAMPTZ NOT NULL`
- `resume_version TEXT NULL`
- `notes TEXT NULL`
- `next_action TEXT NULL`
- `next_action_at TIMESTAMPTZ NULL`
- Unique `job_listing_id` initially, so one application record per listing.

If status-history analytics are included, add `application_status_events` instead of overwriting history without trace. This may be a Should-have if schedule becomes tight.

## 8.5 `sync_tasks`

- `id UUID PRIMARY KEY`
- `source_id UUID NOT NULL REFERENCES sources(id)`
- `status TEXT NOT NULL` — `pending`, `running`, `retry_scheduled`, `succeeded`, `failed`, `cancelled`
- `trigger_type TEXT NOT NULL` — `manual`, `scheduled`, `retry`
- `attempt_count INTEGER NOT NULL DEFAULT 0`
- `max_attempts INTEGER NOT NULL`
- `created_at`, `updated_at TIMESTAMPTZ NOT NULL`
- `started_at`, `finished_at TIMESTAMPTZ NULL`
- `next_attempt_at TIMESTAMPTZ NULL`
- `lease_until TIMESTAMPTZ NULL`
- `fetched_count`, `inserted_count`, `updated_count`, `skipped_count`, `error_count INTEGER NOT NULL DEFAULT 0`
- `last_error_code TEXT NULL`
- `last_error_summary TEXT NULL` — no secrets or entire raw payloads

Prevent multiple concurrent active syncs for one source unless there is a deliberately documented reason. Consider a partial unique index for active states or an equivalent transactional conflict check.

## 8.6 `sync_runs` (optional separate record)

If a sync task and sync-run concepts are kept separately, the task is the durable work item and the run is the outcome/report for an attempt. Keep this distinction clear. For the MVP, it is acceptable to use one task record with attempt history if this substantially reduces complexity, but preserve enough history to diagnose retries and failures.

## 8.7 `outbox_events`

- `id UUID PRIMARY KEY`
- `event_type TEXT NOT NULL`
- `aggregate_id UUID NOT NULL` — e.g. sync task ID
- `payload JSONB NOT NULL`
- `created_at TIMESTAMPTZ NOT NULL`
- `available_at TIMESTAMPTZ NOT NULL DEFAULT now()` — supports scheduled retry publishing
- `published_at TIMESTAMPTZ NULL`
- `attempt_count INTEGER NOT NULL DEFAULT 0`
- `locked_until TIMESTAMPTZ NULL`
- `last_error TEXT NULL`

Add an index suitable for pending/due outbox events, for example an index on `available_at` filtered to unpublished rows if supported by the migration strategy.

## 8.8 Optional `job_listing_events`

Can record first-seen, content-updated, stale, and closed events for historical analysis. Defer if needed; baseline analytics can use `first_seen_at`, `last_seen_at`, sync runs, and application rows. If implemented, make event names and `occurred_at` explicit.

---

# 9. Queue and Distributed-Processing Design

This section is mandatory: RabbitMQ must be used for meaningful asynchronous work, not added decoratively.

## 9.1 Queue topology

Use durable named components with versioned names, e.g.:

- Durable exchange: `rolesignal.events` (topic or direct; choose one, document routing).
- Main durable queue: `rolesignal.sync.v1`.
- Dead-letter exchange: `rolesignal.dlx`.
- Dead-letter queue: `rolesignal.sync.dlq`.
- Persistent messages.

Declare topology idempotently at worker startup or through a documented provisioning step. Use the RabbitMQ Go client `github.com/rabbitmq/amqp091-go`.

## 9.2 Message contract

A minimal JSON message may contain:

```json
{
  "schema_version": 1,
  "event_id": "UUID",
  "task_id": "UUID",
  "attempt": 1,
  "requested_at": "RFC3339 timestamp"
}
```

The message should primarily reference the durable `sync_tasks` row; PostgreSQL remains authoritative. Validate schema version and required fields. Do not put provider secrets or large listing descriptions into messages.

## 9.3 Transactional outbox

Creating a sync task and its initial outbox event must happen in the same PostgreSQL transaction. This prevents the API from committing a task while silently losing the intent to publish it.

Publisher behavior:

1. Claim a bounded batch of due/unpublished outbox records using a short transaction and locking/lease mechanism (e.g. `FOR UPDATE SKIP LOCKED`).
2. Publish persistent messages with publisher confirms enabled. Handle unroutable messages as failures (use mandatory publishing/return handling when supported by the client code).
3. Only mark an outbox record published after the broker confirms successful handling.
4. On error, record the error/attempt and release or expire the claim so the record can be retried.
5. Expect a duplicate if the process crashes after broker confirmation but before the DB update. Consumer idempotency is required.

Do not hold an unnecessarily long PostgreSQL transaction open while doing network publishing. If multiple publishers run, use a clear lease/claim implementation.

## 9.4 Consumer behavior

- Disable automatic acknowledgements.
- Apply a bounded prefetch/concurrency setting.
- Validate the message before processing.
- Load and conditionally claim the referenced task in PostgreSQL.
- If a message refers to an already terminal task or stale attempt, acknowledge it safely without repeating completed side effects.
- Process using a context with explicit timeouts and bounded pagination.
- Commit listing upserts and task outcome/retry scheduling before acknowledging the message.
- On consumer crash/connection loss before acknowledgement, RabbitMQ may redeliver the message; the processing logic must safely handle this.
- Acknowledge only after durable success/failure/retry state is recorded.

## 9.5 Retry model

Use application-managed retry scheduling so transient HTTP errors do not cause a tight RabbitMQ redelivery loop.

- Retry transient network errors, timeouts, HTTP 429, and retryable 5xx responses.
- Respect `Retry-After` where provided, subject to a maximum delay.
- Use exponential backoff with jitter, configurable initial delay, cap, and maximum attempts (initial default: 5 attempts; cap e.g. 15 minutes).
- Treat invalid configuration, missing credentials, unsupported provider types, and most non-retryable 4xx responses as permanent until the user changes configuration.
- In a transaction, update task/run outcome and create an outbox event with future `available_at` for the retry. Then ACK the current message.
- When the max attempt count is exhausted, mark the task `failed`, retain a safe error summary, and surface it in source status/health.
- Use RabbitMQ dead-letter queue for malformed/poison messages or broker-level rejection paths that cannot be handled as valid task outcomes. Do not blindly `Nack(requeue=true)` provider failures because that can create an infinite hot loop.

## 9.6 Idempotency and task state

- Idempotency key for processing is the durable task ID plus attempt number, with task state in PostgreSQL controlling legal transitions.
- Use conditional SQL updates so only eligible tasks transition to `running`.
- Use lease/heartbeat or stale-running recovery where appropriate. Do not let a task remain `running` forever after a worker dies.
- A duplicate message must not create duplicate listings because listing upserts have database-enforced unique constraints.
- Application writes and saved-job creation must be idempotent at the API/database level.

## 9.7 Scheduler concurrency

The scheduler periodically identifies due sources and creates sync tasks. It must be safe to run on multiple worker replicas. Use database transactions/locks/unique constraints to prevent duplicate scheduled tasks for the same source/window.

---

# 10. REST API Contract (MVP)

Base path: `/api/v1`.

Use JSON for API bodies. Return consistent JSON errors. Use UUIDs in public paths. Define every endpoint in OpenAPI and provide request/response examples.

## 10.1 Standard response and errors

Typical success response:

```json
{
  "data": {},
  "meta": {}
}
```

Error response:

```json
{
  "error": {
    "code": "validation_error",
    "message": "A human-readable explanation",
    "details": [],
    "request_id": "UUID-or-request-id"
  }
}
```

Don't expose stack traces, database errors, or secrets in responses. Use appropriate HTTP codes (`200`, `201`, `202`, `204`, `400`, `404`, `409`, `422`, `429`, `500`, `502`/`503` as appropriate) and document them.

## 10.2 Sources and sync

- `GET /api/v1/sources` — list source metadata and configuration/sync health.
- `POST /api/v1/sources` — add a supported source (provider type, display name, board identifier/config; secrets remain in environment variables).
- `GET /api/v1/sources/{sourceID}` — source detail.
- `PATCH /api/v1/sources/{sourceID}` — enable/disable or update allowed config.
- `POST /api/v1/sources/{sourceID}/sync` — create/enqueue manual sync; return `202 Accepted` and task ID.
- `GET /api/v1/sources/{sourceID}/sync-runs` — list recent sync attempts/outcomes.
- `GET /api/v1/sync-tasks/{taskID}` — inspect task state/attempt information.

If no CRUD UI for sources is implemented, provide these endpoints and clear setup instructions.

## 10.3 Listing search

- `GET /api/v1/jobs`
- `GET /api/v1/jobs/{jobID}`
- `POST /api/v1/manual-listings` — create a manually entered listing; don't fetch the submitted URL.
- `POST /api/v1/jobs/{jobID}/save` — save listing.
- `DELETE /api/v1/jobs/{jobID}/save` — unsave listing.
- `GET /api/v1/saved-jobs` — list saved listings.

Suggested query parameters for `GET /jobs`:

- `q`
- `company`
- `source_id`
- `city`
- `region`
- `country_code`
- `work_mode`
- `employment_type`
- `min_experience_years`
- `max_experience_years`
- `min_salary`
- `max_salary`
- `salary_currency`
- `first_seen_after`
- `posted_after`
- `saved` (boolean)
- `application_status`
- `sort` (whitelisted values only, e.g. `newest`, `oldest`, `company`, `relevance`)
- `page` and `page_size` (or a documented cursor strategy; choose one for MVP and apply consistently)

Enforce a maximum page size. Use stable ordering. Avoid promising filters when the required data is absent; make missing values explicit.

## 10.4 Applications

- `GET /api/v1/applications`
- `POST /api/v1/applications` — create an application record for a listing.
- `GET /api/v1/applications/{applicationID}`
- `PATCH /api/v1/applications/{applicationID}` — status, notes, next action, resume version.
- `DELETE /api/v1/applications/{applicationID}` only if justified and documented; otherwise allow status `withdrawn` instead of destructive deletion.

Opening an application link is not equivalent to marking it applied. The user must explicitly update status or confirm submission.

## 10.5 Analytics

- `GET /api/v1/analytics/overview`
- `GET /api/v1/analytics/listings?group_by=day|city|company|source|work_mode`
- `GET /api/v1/analytics/applications`
- `GET /api/v1/analytics/sources`

Limit grouping options to a whitelist. Protect expensive queries with date ranges/limits and suitable indexes.

## 10.6 Operational endpoints

- `GET /healthz` — process liveness.
- `GET /readyz` — readiness of required local dependencies (database and broker, if both are required for API readiness).
- `GET /metrics` — Prometheus format or documented equivalent.

If RabbitMQ is temporarily unavailable, the API may still support database-backed browsing/search; document whether readiness is marked degraded or not-ready based on the actual service contract.

---

# 11. Ranking and Filtering Strategy

MVP ranking must be deterministic and explainable. Do not require LLMs or embeddings.

## 11.1 Hard filters

Apply explicit user-requested filters first (city, country, experience range, work mode, source, date, salary if present). Keep unknown values separate instead of pretending they match.

## 11.2 Basic relevance score

A simple initial score may use:

- Exact/partial title match for user role keywords.
- Keyword matches for user-defined skills.
- Experience range compatibility (prefer explicitly eligible/unknown over explicitly incompatible as appropriate; define behavior).
- Location and work-mode preference.
- Freshness (newly seen listings can rank higher).

Document score weights and return a short reason, e.g. `title match`, `Go keyword`, `Bengaluru`, `first seen today`. Avoid black-box scores in MVP.

Do not equate `first_seen_at` with the employer's posting date. Show both separately where available.

## 11.3 Embeddings/LLM decision gate

Embeddings or LLMs may be proposed only after:

1. Deterministic matching exists and is tested.
2. The project records where deterministic matches fail in a way semantic similarity could plausibly improve.
3. The integration is optional and can be disabled without breaking search.
4. The user approves the change in scope.

No API call to an LLM is needed for the MVP.

---

# 12. Local UI Requirements

The UI is secondary to the backend but the product must be practically usable by its developer.

Minimum views:

1. **Discover:** paginated listing results, filters, sort, save action, link to original posting, source and freshness indicators.
2. **Saved:** saved listings and notes.
3. **Applications:** status pipeline/list, applied date, notes and next action.
4. **Sources/Syncs:** configured sources, last success, last attempt, last error, sync counts, manual sync action.
5. **Analytics:** a few reliable charts/counters for listings first seen, location/work-mode distribution, application states, and source health.

Use accessible labels, display loading/empty/error states, and make unknown/inferred values visible. Don't spend significant time on complex UI polish. A clean simple interface is sufficient.

---

# 13. Metrics and Observability

## 13.1 Product/listing metrics

- New listings first seen per day/week.
- Listing count by normalized city, company, source, work mode, and keyword/skill when available.
- Salary distribution only when currency and pay period can be compared correctly.
- Listings saved and applications by status.
- Personal application funnel based only on recorded statuses.
- Source freshness and stale listing counts.

## 13.2 Collector/queue metrics

- Sync tasks created/completed/failed/retried.
- Source request latency and success/error count per provider.
- Source last-success age.
- Listings fetched/inserted/updated/skipped per sync.
- RabbitMQ queue depth and oldest-message/oldest-task age where practicable.
- Outbox pending count and oldest unpublished event age.
- Task processing duration and attempts.
- Search request latency and error count.

Use low-cardinality metric labels. Do not label metrics with arbitrary job IDs, URLs, company names from user input, or other unbounded values. Put high-cardinality context in structured logs.

## 13.3 Truthful analytics rules

- Distinguish observed listing counts from total market counts.
- Distinguish source-posted date from first-seen timestamp.
- Don't calculate applicant counts, competition levels, or offer probabilities unless a trustworthy source actually provides the necessary information.
- Keep enough history for daily/weekly trends; current-state rows alone cannot reconstruct past totals.
- If a provider returns partial search results, missing listings are not proof of closure.

---

# 14. Security and Privacy Requirements

- Default host port mapping must bind to localhost, for example `127.0.0.1:8080:8080`.
- Do not publish PostgreSQL or RabbitMQ management ports on all network interfaces. If exposed to the host for debugging, bind to localhost only.
- Add `.env`, local database volumes, build artifacts, test result outputs, and other local-only files to `.gitignore` as appropriate.
- Provide `.env.example` with names/placeholders, not real credentials.
- Read secrets from environment variables. Never return secret values from source endpoints.
- Redact auth headers/query secrets from logs and errors.
- Put reasonable request-body, response-body, timeout, concurrency, and pagination limits in place.
- Manual listing URL submission stores a URL but does not trigger server-side fetching, preventing an SSRF primitive in MVP.
- Do not import or store LinkedIn/Naukri cookies/passwords.
- Keep application notes local. Clearly document that a local-only deployment is not intended for access from untrusted networks.
- Use parameterized SQL and explicit sort-field allowlists.

---

# 15. Testing Plan and Failure Experiments

Use deterministic fixtures for provider responses and a fake `JobSource` implementation for unit/integration tests. Live-provider tests should be optional because they need network/API credentials and must not make the regular test suite flaky.

## 15.1 Unit tests

- Provider JSON parsing and field normalization.
- Location normalization (including Bangalore/Bengaluru variants).
- Work-mode and experience parsing with provenance.
- Retryable vs non-retryable error classification.
- Query/filter validation and sorting.
- Deterministic ranking reason/score.
- Task state transitions.
- Message envelope validation.

## 15.2 Database/integration tests

- Migrations apply cleanly to an empty PostgreSQL database.
- Re-ingesting the same `(source_id, external_id)` updates instead of duplicating.
- Concurrent upserts retain a unique record.
- A task and outbox event are committed atomically.
- Rollback leaves no partial task/outbox pair.
- Search filters and pagination behave correctly on fixtures.
- Saved listing/application constraints work.

## 15.3 Queue and distributed failure tests

- Run at least two worker instances and enqueue multiple distinct tasks.
- Publish a duplicate message and verify idempotent behavior.
- Kill a worker before its database outcome is committed; verify the message/task can recover.
- Simulate an ambiguous publisher outcome (publish succeeded but DB `published_at` update did not); verify duplicate messages are safe.
- Stop RabbitMQ temporarily; verify pending outbox records are published after recovery.
- Simulate a network timeout/429/500 from one source; verify retry scheduling and that other sources continue.
- Simulate permanent invalid credentials; verify visible terminal failure rather than infinite retries.
- Poison/malformed message goes to DLQ or another documented safe failure path without infinite requeue.
- Ensure a stale `running` task can be recovered after its lease expires.

## 15.4 End-to-end tests

- Start the stack.
- Seed a test source fixture.
- Trigger sync through the API.
- Wait for worker completion using polling with a bounded timeout.
- Query listing results with city/role filters.
- Save a listing.
- Create/update an application record.
- Verify analytics and source health reflect the action.

## 15.5 Performance tests

Create a repeatable synthetic dataset (e.g. 10,000 listings). Measure search p50/p95, ingestion throughput, memory profile if practicable, sync duration, and queue processing. Record machine/container resources and query shape. Do not put unmeasured numbers in the README or resume.

## 15.6 Required developer checks

At minimum:

```bash
gofmt -w .
go vet ./...
go test ./...
go test -race ./...
```

Run integration tests with PostgreSQL/RabbitMQ services available. If any command is not run, explicitly say so in the completion summary.

---

# 16. Docker Compose and Configuration

## 16.1 Services

Compose should define:

- `api` — Go Gin HTTP server.
- `worker` — same Go module, worker command.
- `postgres` — persistent named volume and health check.
- `rabbitmq` — durable broker with persistent volume and health check; management UI optional and localhost-bound only.

The `api` and `worker` may be built from one Dockerfile with different commands. Container dependencies must wait for health checks/readiness rather than relying only on container start order.

## 16.2 Configuration variables

Provide an `.env.example` covering at least:

```dotenv
APP_ENV=development
HTTP_ADDR=:8080
DATABASE_URL=postgres://rolesignal:rolesignal_dev_only@postgres:5432/rolesignal?sslmode=disable
RABBITMQ_URL=amqp://rolesignal:rolesignal_dev_only@rabbitmq:5672/
SYNC_WORKER_COUNT=2
SYNC_DEFAULT_INTERVAL_SECONDS=21600
SYNC_MAX_ATTEMPTS=5
SYNC_INITIAL_BACKOFF_SECONDS=30
SYNC_MAX_BACKOFF_SECONDS=900
HTTP_CLIENT_TIMEOUT_SECONDS=20
ADZUNA_APP_ID=
ADZUNA_APP_KEY=
```

These are illustrative local defaults only; don't ship production credentials. Ensure the Compose-created database/broker credentials match the development DSNs. If secrets are not configured, the API/worker should still start and mark the relevant source unconfigured.

The Go server listens on `:8080` inside the container, while host mapping is bound to `127.0.0.1:8080` by default.

## 16.3 Expected developer commands

Document commands analogous to:

```bash
cp .env.example .env
docker compose up --build -d
docker compose ps
docker compose logs -f api worker
go test ./...
docker compose down
```

Document whether migrations execute from the API entrypoint, a one-off migration command, or a separate `migrate` service. Choose one reproducible approach and prevent multiple replicas from racing to run the same migration set.

---

# 17. Suggested Repository Structure

Keep packages simple and aligned with responsibility. Adjust when actual implementation suggests a cleaner shape.

```text
rolesignal/
├── cmd/
│   ├── api/
│   │   └── main.go
│   └── worker/
│       └── main.go
├── internal/
│   ├── config/
│   ├── domain/
│   ├── api/
│   │   ├── handlers/
│   │   ├── middleware/
│   │   └── response/
│   ├── sources/
│   │   ├── adzuna/
│   │   ├── greenhouse/
│   │   ├── lever/
│   │   ├── ashby/
│   │   └── manual/
│   ├── ingestion/
│   ├── jobs/
│   ├── applications/
│   ├── analytics/
│   ├── repository/
│   ├── queue/
│   ├── outbox/
│   ├── scheduler/
│   ├── worker/
│   └── observability/
├── migrations/
├── web/                  # minimal local UI/static assets if not embedded elsewhere
├── tests/
│   ├── fixtures/
│   └── integration/
├── docs/
│   ├── feasibility.md
│   ├── requirements.md
│   ├── hld.md
│   ├── lld.md
│   ├── test-plan.md
│   └── adr/
├── .env.example
├── .gitignore
├── Dockerfile
├── compose.yaml
├── go.mod
├── go.sum
├── openapi.yaml
└── README.md
```

Do not create empty packages just to match this tree. Add a package when it has real responsibility.

---

# 18. Four-Week Delivery Plan (56 Hours)

## Week 1 — Feasibility, requirements and skeleton (14 hours)

- Validate source API access, data shape, coverage and policy constraints.
- Record source feasibility and chosen initial adapters.
- Finalize MVP FR/NFR, data model, HLD and key ADRs.
- Initialize Go module, Gin, configuration, logging, health endpoints and migrations.
- Start PostgreSQL/RabbitMQ through Docker Compose.

**Exit criteria:** Clean local startup, migrations work, `/healthz` works, and at least one real/fixture source response has been understood.

## Week 2 — Core data and synchronous ingestion path (14 hours)

- Implement repository and domain models.
- Implement one source adapter end-to-end.
- Implement normalized listing upserts and source-level uniqueness.
- Implement search/filter/pagination endpoints.
- Add tests for parsing, normalization, and idempotent upsert.

**Exit criteria:** A listing dataset can be loaded safely and queried through the REST API.

## Week 3 — RabbitMQ and distributed processing (14 hours)

- Implement task/outbox schema and atomic task+outbox creation.
- Implement outbox publisher with publisher confirms and recoverable publish state.
- Implement RabbitMQ topology, consumer acknowledgements, bounded prefetch/concurrency, task claiming, and idempotency.
- Add retries/backoff, terminal failure handling, and stale-task recovery.
- Test multiple workers and crash/failure scenarios.

**Exit criteria:** Sync requests are asynchronous and durable; worker/broker failure is recoverable; duplicate processing is safe.

## Week 4 — Product usability, metrics, tests and docs (14 hours)

- Add more source adapters if feasible, plus manual listing capture.
- Implement saved jobs and application tracking.
- Add local UI and analytics overview.
- Add logs/metrics/health details and operational error messages.
- Complete end-to-end/failure/performance tests.
- Finish README, OpenAPI, design docs, diagrams and demo.

**Exit criteria:** Another developer can run the system from a fresh checkout, search/filter listings, track an application, inspect source health, and reproduce tests.

If schedule slips, prioritize: source ingestion, useful filtering, PostgreSQL correctness, RabbitMQ/outbox/recovery, Docker reproducibility, and tests. Defer advanced analytics/UI polish and optional connectors before cutting correctness guarantees.

---

# 19. README and Demo Requirements

The README must include:

- Problem and intended user.
- Features and explicit limitations/source coverage caveat.
- Architecture diagram.
- Technology stack and why each major component is present.
- Local setup, configuration, and run commands.
- How to configure Adzuna credentials if used, and how to add public ATS boards.
- How to manually capture listings from sources without supported automation.
- API examples/curl commands and link to OpenAPI.
- How RabbitMQ, the outbox, consumer acknowledgements, retries, and idempotency work.
- How to run unit/integration/race tests.
- How to reproduce failure experiments.
- Measured results with machine/configuration details and clear caveats.
- Limitations and future work.

Demo flow:

1. Start RoleSignal locally.
2. Display configured sources and source health.
3. Trigger a sync and show the API returns quickly with a task ID.
4. Show RabbitMQ/worker processing and resulting listing records.
5. Search/filter by city and role, inspect source/freshness and open the source URL.
6. Save one listing and create/update an application record.
7. Demonstrate a source failure/retry or worker restart and show recovery.
8. Display honest metrics and explain limitations.

---

# 20. Acceptance Checklist — Definition of Done

The MVP is complete only when the following are true:

## Product

- [ ] The user can browse, filter, sort, and paginate collected listings.
- [ ] Listings show original application URL, source, first-seen/last-seen metadata, and unknown/inferred fields honestly.
- [ ] The user can manually add a listing without the server fetching its URL.
- [ ] The user can save listings and track applications.
- [ ] The UI/API makes source failures distinguishable from zero results.

## Data and API

- [ ] Migrations work on a clean database.
- [ ] API contracts are documented in OpenAPI.
- [ ] Inputs are validated; SQL is parameterized.
- [ ] Same-source duplicate ingest is idempotent.
- [ ] Search indexes are based on actual query patterns.

## Queue and distributed processing

- [ ] A sync request and outbox record are committed atomically.
- [ ] Publisher confirms are enabled and handled.
- [ ] Consumer manual acknowledgements are used.
- [ ] Transient failures retry with bounded backoff.
- [ ] Permanent failures are visible and don't retry forever.
- [ ] Duplicate messages are safe.
- [ ] Worker crash and RabbitMQ outage/recovery tests pass.
- [ ] At least two worker replicas can safely process tasks.
- [ ] Stale running work can recover after worker failure.

## Operations/security

- [ ] Docker Compose starts the stack from a fresh checkout.
- [ ] Host binding is localhost-only by default.
- [ ] Secrets are not committed or returned through APIs/logs.
- [ ] Health checks and useful structured logs exist.
- [ ] `go test ./...`, `go vet ./...`, and `go test -race ./...` were run, with outcomes documented.
- [ ] Performance metrics are reported only if actually measured.
- [ ] README and troubleshooting steps are complete.

---

# 21. Architecture Decision Records (Initial Decisions)

Codex should create short ADR files for these decisions and may revise them only when new evidence justifies the change.

## ADR-001: Go + Gin REST API

**Decision:** Use Go and Gin for the primary API.  
**Reason:** The project is intended to develop Go backend/API skills; REST is sufficient for local dashboard and CLI clients.  
**Consequences:** No gRPC in the MVP. Add it later only for a real use case.

## ADR-002: PostgreSQL as authoritative data store

**Decision:** Use PostgreSQL for normalized listings, application state, source sync state, and transactional outbox.  
**Reason:** Strong constraints, transactions, flexible querying and meaningful database engineering.  
**Consequences:** Need migrations, indexes, transactions, and query-plan validation.

## ADR-003: RabbitMQ for asynchronous sync tasks

**Decision:** Use RabbitMQ for source synchronization work.  
**Reason:** Source fetches are slow/unreliable and should not block HTTP requests; multiple workers make real use of the queue.  
**Consequences:** Need broker configuration, durable messages, confirms, acknowledgements, retries, monitoring and local Docker service.

## ADR-004: Transactional outbox

**Decision:** Create sync task and outbox event in one DB transaction; publish asynchronously.  
**Reason:** Prevent a task commit from being lost due to a separate failed publish.  
**Consequences:** Outbox publisher and retention/cleanup policy are required; duplicate publishing remains possible and consumers must be idempotent.

## ADR-005: At-least-once and idempotent processing

**Decision:** Build for at-least-once message delivery, not exactly-once semantics.  
**Reason:** Network/process failures can make publish/ack outcomes ambiguous.  
**Consequences:** Durable task state, conditional transitions, unique listing constraints and idempotent handlers are mandatory.

## ADR-006: Supported APIs plus manual capture; no protected-site scraping

**Decision:** Integrate documented/public sources and accept manually captured LinkedIn/Naukri links/data.  
**Reason:** Avoid brittle or unauthorized login scraping and focus time on useful ingestion, matching, storage and application workflow.  
**Consequences:** Coverage is intentionally incomplete and must be disclosed.

## ADR-007: No LLM/vector DB in MVP

**Decision:** Use deterministic matching initially.  
**Reason:** The value proposition is fresh, well-filtered listings and reliable collection; embeddings add complexity before a baseline exists.  
**Consequences:** Measure ranking quality before proposing semantic search.

---

# 22. Immediate Next Action for Codex

Do not start by implementing all features. First:

1. Inspect the repository and report its current state.
2. Read the relevant official docs linked in this handoff for the intended first providers and RabbitMQ reliability patterns.
3. Perform a small source feasibility spike (using fixtures if credentials/network access are unavailable). Determine the initial actual connectors, required credentials, rate limits, fields, and limitations.
4. Propose a concrete milestone plan mapped to this document and a 56-hour target.
5. Implement Milestone 1 only after recording the feasibility result and the proposed plan.

The finished product must be genuinely useful even with only a modest, well-supported source set. Prioritize trustworthy listings, source freshness, personal filters, application tracking, and reliable asynchronous ingestion over raw scrape volume.

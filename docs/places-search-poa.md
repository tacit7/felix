# Places Search with Aliases - Plan of Attack

**Objective**: Ship reliable place-name search that handles aliases and messy user input with PostgreSQL; keep it simple now, extensible later.

## Scope

- Two tables: `places`, `place_aliases`
- Normalization with `unaccent` and `lower`
- Trigram search for exact, prefix, fuzzy
- One SQL function `search_places`
- One service method and one HTTP endpoint
- Seed a handful of aliases; add logging for misses; weekly curation

## Guardrails and Non-Negotiables

- Postgres 13+; `pg_trgm` and `unaccent` enabled
- Migrations are reversible; zero downtime compatible
- Env config for similarity threshold; default 0.35
- Feature flag for the new endpoint; return both old and new results for short overlap if needed

---

## Implementation Steps

### Step 1. Schema and Indexes

**Deliverables**:
- Migration creating `places`, `place_aliases` with generated normalized columns
- GIN trigram indexes on `canonical_norm`, `alias_norm`
- Unique index on `code` when present

**Acceptance**:
- EXPLAIN on prefix and trigram queries uses GIN; no sequential scan on tables over 10k rows

### Step 2. Seed Data and Admin Scripts

**Deliverables**:
- Seed SQL or Mix task to upsert a small list: USVI, NYC, LA, national parks
- Helper script to batch-insert aliases per place

**Acceptance**:
- Running the seed twice is idempotent
- USVI has at least 5 common variants; search returns the canonical row first

### Step 3. Search Function in SQL

**Deliverables**:
- `search_places(q_raw text, limit_n int)` with exact, prefix, then fuzzy passes
- Threshold from `current_setting('app.search_limit', true)` or passed via wrapper

**Acceptance**:
- `SELECT * FROM search_places('usvi')` returns United States Virgin Islands as top result with score ≥ 0.9 in exact/prefix and ≥ 0.35 in fuzzy
- Function is marked STABLE; uses generated columns; no normalization in WHERE clauses

### Step 4. Service Layer

**Deliverables**:
Backend module `PlaceSearch` that:
- Preprocesses query: trim; collapse whitespace; unaccent optional; refuses empty string
- Calls `search_places($q, $limit)`
- Deduplicates by place_id
- Applies final ranking tie-breakers: canonical over alias; country over region over city over poi; popularity as tie breaker
- Caps to limit with deterministic sort

**Acceptance**:
- Unit tests for preprocessing and ranking tie-breakers
- Deterministic ordering for same score; no jitter between calls

### Step 5. HTTP Endpoint

**Deliverables**:
- `GET /api/places/search?q=USVI&limit=10`
- Response shape:
```json
{
  "query": "USVI",
  "results": [
    {"id": 123, "label": "United States Virgin Islands", "kind": "region", "score": 0.98, "code": "USVI"},
    {"id": 124, "label": "Saint Thomas", "kind": "city", "score": 0.71, "code": "STT"}
  ]
}
```
- Strict rate limit; 10 req/s per IP by default
- 422 if q is missing or < 2 chars; 200 with empty array for no hits

**Acceptance**:
- Contract tests; example fixtures included

### Step 6. Logging and Curation Loop

**Deliverables**:
- Log misses: when 0 results, write to `place_query_log` with query, timestamp, client_locale, ip_hash
- Admin script: top-N missed queries for last 7 days; suggest candidate mappings using fuzzy match over places with similarity ≥ 0.25
- CLI action to promote a missed query to an alias for a chosen place_id

**Acceptance**:
- Daily job produces a CSV of top 100 missed queries with suggested matches and scores
- Adding an alias reduces that miss from the report on the next run

---

## Quality Gates

### Step 7. Test Corpus

**Deliverables**:
- Test corpus of 40 queries; includes abbreviations, diacritics, typos
- Snapshot tests asserting top 3 ids in order for each query

**Acceptance**:
- 90% of corpus returns the expected top result first; 100% of corpus returns it within top 3
- Adding new aliases cannot drop existing corpus accuracy; CI fails on regression

### Step 8. Performance Baseline

**Deliverables**:
- Bench script that warms cache, then runs 1k random queries; captures p95 latency and hit ratio
- Explain analyze for worst 5 queries

**Targets**:
- p95 under 25 ms in Postgres for 10k rows; under 60 ms for 100k rows
- No sequential scans on hot path

### Step 9. Configurability

**Deliverables**:
Env vars:
- `PLACE_SEARCH_LIMIT` default 10
- `PLACE_SEARCH_TRIGRAM_THRESHOLD` default 0.35
- `PLACE_SEARCH_MIN_QUERY_LENGTH` default 2

**Acceptance**:
- Changing env values affects behavior without code changes; documented defaults

---

## Rollout and Rollback

### Rollout
- Ship behind feature flag; mirror old search for 48 hours; compare logs
- If delta in miss rate improves or stays flat, switch clients to new endpoint

### Rollback
- Flag off; no schema rollback required; function is isolated

---

## Risks and Mitigations

- **Garbage fuzzy hits**: keep threshold ≥ 0.35; popularity and kind tie-breakers reduce nonsense
- **Alias collisions**: uniqueness is per place; if two places fight, prefer canonical of higher kind; review collisions in curation report
- **Unbounded LIKE**: use generated normalized columns so indexes engage; never wrap the left-hand side of LIKE in a function

---

## Timeline

- **Day 1**: Migrations, indexes, seed; local tests pass
- **Day 2**: SQL function, service wrapper; endpoint scaffold; unit tests
- **Day 3**: Logging, curation script, test corpus; performance baseline
- **Day 4**: Staging rollout behind flag; p95 and accuracy checks; tweak threshold; go live

---

## Implementation Status

- [ ] Step 1: Schema and indexes
- [ ] Step 2: Seed data and admin scripts
- [ ] Step 3: Search function in SQL
- [ ] Step 4: Service layer
- [ ] Step 5: HTTP endpoint
- [ ] Step 6: Logging and curation loop
- [ ] Step 7: Quality gates
- [ ] Step 8: Performance baseline
- [ ] Step 9: Configurability
- [ ] Step 10: Rollout

**Target**: Fix USVI search issue while building robust, extensible place search foundation.
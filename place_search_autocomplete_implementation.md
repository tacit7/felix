# Multitype Place Autocomplete: PostgreSQL Implementation Guide

This guide describes a production-ready autocomplete for **countries, cities, and POIs** (e.g., “Grand Canyon”). It covers schema, normalization, indexes, queries, API contract, ingestion, and ops.

---

## Overview

**Goals**
- Fast suggestions as the user types (≤150–250 ms DB time).
- Support prefix, contains, and mild typo tolerance.
- Handle aliases and multiple languages.
- Rank results sensibly by type, popularity, and proximity.

**Tech**
- PostgreSQL 14+
- Extensions: `unaccent`, `pg_trgm`

**Client rules**
- Debounce 150–250 ms.
- Start matching at 2 chars (prefix), allow fuzzy from 3+ chars.
- Limit 10–12 results per request.
- Cancel in-flight requests when input changes.

---

## 1) Schema

### 1.1 `places`
Entities for countries, admin regions, cities/localities, and POIs.

```sql
CREATE TABLE places (
  id            BIGSERIAL PRIMARY KEY,
  place_type    SMALLINT NOT NULL,        -- 1=country, 2=region/admin1, 3=city/locality, 4=locality/suburb, 5=poi/park
  name          TEXT NOT NULL,            -- canonical primary label
  country_iso2  CHAR(2),                  -- ISO 3166-1 alpha-2
  admin1_code   TEXT,                     -- e.g., "US-AZ"
  parent_id     BIGINT REFERENCES places(id) ON DELETE SET NULL,
  lat           DOUBLE PRECISION,
  lon           DOUBLE PRECISION,
  population    INTEGER,                  -- null for POIs
  popularity    REAL,                     -- blended app metric; optional
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX places_country_type_idx ON places (country_iso2, place_type);
CREATE INDEX places_popularity_idx ON places (popularity DESC NULLS LAST);
CREATE INDEX places_population_idx ON places (population DESC NULLS LAST);
```

### 1.2 `place_names`
Alias table for multilingual and alternate spellings.

```sql
CREATE TABLE place_names (
  id         BIGSERIAL PRIMARY KEY,
  place_id   BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,        -- alias label
  lang       TEXT,                 -- 'en', 'es', 'de', etc.
  is_primary BOOLEAN DEFAULT FALSE,
  source     TEXT,                 -- 'osm', 'wof', 'natural_earth', 'manual', etc.
  name_norm  TEXT                  -- generated below after we create normalize()
);
CREATE INDEX place_names_place_id_idx ON place_names (place_id);
```

---

## 2) Normalization

We normalize to handle case, accents, punctuation, acronyms, and common synonyms like “saint” ↔ “st”, “mount” ↔ “mt”, etc.

### 2.1 Enable extensions
```sql
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

### 2.2 Mapping table for replacements
```sql
CREATE TABLE normalize_map (
  from_text TEXT PRIMARY KEY,
  to_text   TEXT NOT NULL
);

INSERT INTO normalize_map(from_text, to_text) VALUES
  ('saint', 'st'), ('st.', 'st'),
  ('mount', 'mt'), ('mt.', 'mt'),
  ('fort', 'ft'), ('ft.', 'ft'),
  ('avenue', 'ave'), ('road', 'rd'),
  ('united states', 'usa'), ('u.s.', 'usa'), ('u.s.a.', 'usa'),
  ('the ', '');
```

### 2.3 Normalize function
> Adjust the replacements to your needs. Keep it deterministic.

```sql
CREATE OR REPLACE FUNCTION normalize(input TEXT)
RETURNS TEXT LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  s TEXT;
  r RECORD;
BEGIN
  IF input IS NULL THEN
    RETURN NULL;
  END IF;

  -- base: lowercase + unaccent + trim + collapse spaces + strip dots in acronyms
  s := lower(unaccent(input));
  s := regexp_replace(s, '\.', '', 'g');          -- remove periods in acronyms
  s := regexp_replace(s, '\s+', ' ', 'g');
  s := btrim(s);

  -- remove leading articles in common languages
  s := regexp_replace(s, '^(the|le|la|los|las|el|die|der|das)\s+', '', 'i');

  -- apply mapping table (simple replaces; order matters a bit)
  FOR r IN SELECT from_text, to_text FROM normalize_map LOOP
    s := regexp_replace(s, '\m' || r.from_text || '\M', r.to_text, 'g'); -- word-boundary replace
  END LOOP;

  RETURN s;
END;
$$;
```

### 2.4 Add generated column
```sql
ALTER TABLE place_names
  ADD COLUMN name_norm TEXT GENERATED ALWAYS AS (normalize(name)) STORED;
```

---

## 3) Indexes

Use prefix for early keystrokes and trigram for fuzzier matching.

```sql
-- Prefix and equality (supports LIKE 'foo%')
CREATE INDEX place_names_prefix_idx
  ON place_names (name_norm text_pattern_ops);

-- Fuzzy/contains/typo tolerance
CREATE INDEX place_names_trgm_idx
  ON place_names USING gin (name_norm gin_trgm_ops);
```

---

## 4) Query

Two-stage logic: favor prefix; allow trigram from 3+ chars. Rank by type, prefix/exact, distance, popularity/population, and tie-break by name.

```sql
-- Optional helper for distance ranking (Haversine or great-circle)
CREATE OR REPLACE FUNCTION great_circle_distance(lat1 float8, lon1 float8, lat2 float8, lon2 float8)
RETURNS float8 LANGUAGE sql IMMUTABLE AS $$
  SELECT 6371.0 * acos(
    least(1.0, greatest(-1.0,
      sin(radians(lat1))*sin(radians(lat2)) +
      cos(radians(lat1))*cos(radians(lat2))*cos(radians(lon2 - lon1))
    ))
  );
$$;

-- Main autocomplete query (use as-is or wrap in a SQL function)
WITH q AS (
  SELECT normalize($1) AS q,
         $2::text  AS cc,    -- optional country_iso2
         $3::float8 AS ulat, -- optional user lat
         $4::float8 AS ulon  -- optional user lon
),
candidates AS (
  SELECT
    p.id, p.place_type, p.name, p.country_iso2, p.admin1_code,
    p.lat, p.lon, p.population, p.popularity,
    pn.name AS matched_alias,
    (pn.name_norm LIKE q.q || '%')::int AS is_prefix,
    (pn.name_norm = q.q)::int AS is_exact,
    (pn.name_norm <-> q.q)          AS trigram_dist,
    CASE
      WHEN q.ulat IS NULL OR q.ulon IS NULL THEN NULL
      ELSE great_circle_distance(p.lat, p.lon, q.ulat, q.ulon)
    END AS user_km
  FROM q
  JOIN place_names pn ON TRUE
  JOIN places p ON p.id = pn.place_id
  WHERE
    (q.cc IS NULL OR p.country_iso2 = q.cc)
    AND (
      (length(q.q) >= 2 AND pn.name_norm LIKE q.q || '%')
      OR (length(q.q) >= 3 AND pn.name_norm % q.q)
    )
)
SELECT id, name, place_type, country_iso2, admin1_code, lat, lon
FROM candidates
ORDER BY
  CASE place_type WHEN 1 THEN 0 WHEN 3 THEN 1 WHEN 5 THEN 2 WHEN 2 THEN 3 ELSE 4 END,
  is_prefix DESC,
  is_exact DESC,
  trigram_dist ASC,
  COALESCE(popularity, log(LEAST(NULLIF(population,0), 50000000))) DESC,
  name ASC
LIMIT 12;
```

**Notes**
- For general queries, the type order favors countries then cities then POIs. Tune as needed.
- Use statement timeout ~150–250 ms for this endpoint.

---

## 5) SQL Function Wrapper

```sql
CREATE OR REPLACE FUNCTION place_autocomplete(
  q_raw TEXT,
  country TEXT DEFAULT NULL,
  user_lat DOUBLE PRECISION DEFAULT NULL,
  user_lon DOUBLE PRECISION DEFAULT NULL
)
RETURNS TABLE (
  id BIGINT,
  label TEXT,
  type SMALLINT,
  country_iso2 CHAR(2),
  admin1_code TEXT,
  lat DOUBLE PRECISION,
  lon DOUBLE PRECISION
) LANGUAGE sql STABLE AS $$
WITH q AS (
  SELECT normalize(q_raw) AS q,
         country::text  AS cc,
         user_lat::float8 AS ulat,
         user_lon::float8 AS ulon
),
candidates AS (
  SELECT
    p.id, p.place_type, p.name, p.country_iso2, p.admin1_code,
    p.lat, p.lon, p.population, p.popularity,
    pn.name AS matched_alias,
    (pn.name_norm LIKE q.q || '%')::int AS is_prefix,
    (pn.name_norm = q.q)::int AS is_exact,
    (pn.name_norm <-> q.q)          AS trigram_dist,
    CASE
      WHEN q.ulat IS NULL OR q.ulon IS NULL THEN NULL
      ELSE great_circle_distance(p.lat, p.lon, q.ulat, q.ulon)
    END AS user_km
  FROM q
  JOIN place_names pn ON TRUE
  JOIN places p ON p.id = pn.place_id
  WHERE
    (q.cc IS NULL OR p.country_iso2 = q.cc)
    AND (
      (length(q.q) >= 2 AND pn.name_norm LIKE q.q || '%')
      OR (length(q.q) >= 3 AND pn.name_norm % q.q)
    )
)
SELECT id, name, place_type, country_iso2, admin1_code, lat, lon
FROM candidates
ORDER BY
  CASE place_type WHEN 1 THEN 0 WHEN 3 THEN 1 WHEN 5 THEN 2 WHEN 2 THEN 3 ELSE 4 END,
  is_prefix DESC,
  is_exact DESC,
  trigram_dist ASC,
  COALESCE(popularity, log(LEAST(NULLIF(population,0), 50000000))) DESC,
  name ASC
LIMIT 12;
$$;
```

---

## 6) API Contract

**Request**  
`GET /api/places/autocomplete?q=gran&country=US&lat=36.06&lon=-112.14`

**Response**
```json
[
  {"id": 1001, "label": "Grand Canyon National Park", "type": 5, "country_iso2": "US", "admin1_code": "US-AZ", "lat": 36.06, "lon": -112.14},
  {"id": 2001, "label": "Granada", "type": 3, "country_iso2": "ES"}
]
```

**Server behavior**
- If `q.length < 2`: return empty list.
- Use function `place_autocomplete(q, country, lat, lon)`.
- Limit to 12 items. Enforce statement timeout and total API timeout.
- Consider small TTL caching for hot prefixes `(country, q_prefix)`.

---

## 7) Data Ingestion

**Recommended sources**
- Countries/regions: ISO 3166, Natural Earth
- Cities/localities: GeoNames, Who’s On First (WOF)
- POIs/parks: OpenStreetMap + curated list of famous parks/landmarks

**Steps**
1. Load into staging tables as provided.
2. Deduplicate by geometry + admin + string similarity on canonical names.
3. Upsert into `places` and insert aliases into `place_names`.
4. Compute `popularity` (blend of population, pageviews, app clicks).

**Example upsert skeleton**
```sql
-- Insert a canonical place
INSERT INTO places (place_type, name, country_iso2, admin1_code, lat, lon, population, popularity)
VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
ON CONFLICT DO NOTHING
RETURNING id;

-- Insert aliases
INSERT INTO place_names (place_id, name, lang, is_primary, source)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT DO NOTHING;
```

---

## 8) Performance & Ops

- `work_mem`: ensure enough for GIN operations on your instance size.
- Reindex occasionally if bulk loads are heavy.
- Analyze tables after large ingests: `ANALYZE places; ANALYZE place_names;`
- Pin this read path to a **read replica** if traffic is high.
- Consider a **skinny materialized view** if join pressure grows:

```sql
CREATE MATERIALIZED VIEW place_search AS
SELECT
  pn.place_id,
  pn.name_norm,
  p.place_type,
  p.country_iso2,
  p.admin1_code,
  p.lat,
  p.lon,
  p.population,
  p.popularity
FROM place_names pn
JOIN places p ON p.id = pn.place_id;

CREATE INDEX place_search_prefix_idx ON place_search (name_norm text_pattern_ops);
CREATE INDEX place_search_trgm_idx   ON place_search USING gin (name_norm gin_trgm_ops);
CREATE INDEX place_search_country_type_idx ON place_search (country_iso2, place_type);

-- refresh
REFRESH MATERIALIZED VIEW CONCURRENTLY place_search;
```

---

## 9) Testing

- Seed representative data: mixed languages, diacritics, synonyms.
- Test cases:
  - 2-char prefix hits multiple types.
  - Fuzzy recovery: “grnd canyn” → Grand Canyon.
  - Country scoping: `country=US` limits EU cities.
  - Ranking stability: deterministic order for ties.
- Load test with 95th percentile latency budget ≤ 200 ms at DB.

---

## 10) SQLite Note (Offline)

For on-device, prefix-only autocomplete is OK with **SQLite FTS5**:

```sql
CREATE VIRTUAL TABLE place_fts USING fts5(
  name, place_id UNINDEXED, place_type UNINDEXED, country_iso2 UNINDEXED,
  tokenize = 'unicode61 remove_diacritics 2'
);
-- Query: SELECT place_id FROM place_fts WHERE place_fts MATCH 'gran*' LIMIT 12;
```

No real fuzzy/contains at scale; use Postgres in the backend for that.

---

## 11) Minimal Rollout Checklist

- [ ] `unaccent`, `pg_trgm` enabled
- [ ] `normalize()` and `normalize_map` applied
- [ ] Schemas created, generated columns populated
- [ ] Indexes created
- [ ] Autocomplete function deployed with statement timeout
- [ ] API wired with debounce and cancellation on the client
- [ ] Basic popularity and tie-breaking rules tuned
- [ ] Ingestion pipeline established and tables analyzed

---

## License

Feel free to adapt. Attribution appreciated.

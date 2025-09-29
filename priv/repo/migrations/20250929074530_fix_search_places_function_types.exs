defmodule RouteWiseApi.Repo.Migrations.FixSearchPlacesFunctionTypes do
  use Ecto.Migration

  def up do
    # Drop the existing function first
    execute "DROP FUNCTION IF EXISTS search_places(text, int)"

    # Create the corrected search function with proper return types
    execute """
    CREATE OR REPLACE FUNCTION search_places(q_raw text, limit_n int DEFAULT 10)
    RETURNS TABLE (
      place_id int,
      name character varying(255),
      code character varying(255),
      kind character varying(255),
      latitude decimal(10,6),
      longitude decimal(10,6),
      popularity int,
      metadata jsonb,
      matched_alias text,
      match_type text,
      similarity_score real
    ) AS $$
    DECLARE
      q_norm text;
      trigram_threshold real;
    BEGIN
      -- Normalize input query
      q_norm := lower(immutable_unaccent(trim(q_raw)));

      -- Get similarity threshold from app setting or use default
      trigram_threshold := coalesce(
        nullif(current_setting('app.search_similarity_threshold', true), '')::real,
        0.35
      );

      -- Return early if query is empty after normalization
      IF length(q_norm) = 0 THEN
        RETURN;
      END IF;

      -- Phase 1: Exact matches on canonical names
      RETURN QUERY
      SELECT DISTINCT
        p.id,
        p.name,
        p.code,
        p.kind,
        p.latitude,
        p.longitude,
        p.popularity,
        p.metadata,
        p.name::text as matched_alias,
        'exact_canonical'::text as match_type,
        1.0::real as similarity_score
      FROM places p
      WHERE p.canonical_norm = q_norm
      ORDER BY p.popularity DESC, p.name ASC
      LIMIT limit_n;

      -- If we have results, return them
      IF FOUND THEN
        RETURN;
      END IF;

      -- Phase 2: Exact matches on aliases
      RETURN QUERY
      SELECT DISTINCT
        p.id,
        p.name,
        p.code,
        p.kind,
        p.latitude,
        p.longitude,
        p.popularity,
        p.metadata,
        a.alias::text as matched_alias,
        'exact_alias'::text as match_type,
        1.0::real as similarity_score
      FROM places p
      JOIN place_aliases a ON p.id = a.place_id
      WHERE a.alias_norm = q_norm
      ORDER BY a.priority DESC, p.popularity DESC, p.name ASC
      LIMIT limit_n;

      -- If we have results, return them
      IF FOUND THEN
        RETURN;
      END IF;

      -- Phase 3: Prefix matches on canonical names
      RETURN QUERY
      SELECT DISTINCT
        p.id,
        p.name,
        p.code,
        p.kind,
        p.latitude,
        p.longitude,
        p.popularity,
        p.metadata,
        p.name::text as matched_alias,
        'prefix_canonical'::text as match_type,
        0.9::real as similarity_score
      FROM places p
      WHERE p.canonical_norm LIKE q_norm || '%'
      ORDER BY length(p.canonical_norm) ASC, p.popularity DESC, p.name ASC
      LIMIT limit_n;

      -- If we have results, return them
      IF FOUND THEN
        RETURN;
      END IF;

      -- Phase 4: Prefix matches on aliases
      RETURN QUERY
      SELECT DISTINCT
        p.id,
        p.name,
        p.code,
        p.kind,
        p.latitude,
        p.longitude,
        p.popularity,
        p.metadata,
        a.alias::text as matched_alias,
        'prefix_alias'::text as match_type,
        0.9::real as similarity_score
      FROM places p
      JOIN place_aliases a ON p.id = a.place_id
      WHERE a.alias_norm LIKE q_norm || '%'
      ORDER BY length(a.alias_norm) ASC, a.priority DESC, p.popularity DESC, p.name ASC
      LIMIT limit_n;

      -- If we have results, return them
      IF FOUND THEN
        RETURN;
      END IF;

      -- Phase 5: Fuzzy matches on canonical names (trigram similarity)
      RETURN QUERY
      SELECT DISTINCT
        p.id,
        p.name,
        p.code,
        p.kind,
        p.latitude,
        p.longitude,
        p.popularity,
        p.metadata,
        p.name::text as matched_alias,
        'fuzzy_canonical'::text as match_type,
        similarity(p.canonical_norm, q_norm) as similarity_score
      FROM places p
      WHERE similarity(p.canonical_norm, q_norm) >= trigram_threshold
      ORDER BY similarity(p.canonical_norm, q_norm) DESC, p.popularity DESC, p.name ASC
      LIMIT limit_n;

      -- If we have results, return them
      IF FOUND THEN
        RETURN;
      END IF;

      -- Phase 6: Fuzzy matches on aliases (trigram similarity)
      RETURN QUERY
      SELECT DISTINCT
        p.id,
        p.name,
        p.code,
        p.kind,
        p.latitude,
        p.longitude,
        p.popularity,
        p.metadata,
        a.alias::text as matched_alias,
        'fuzzy_alias'::text as match_type,
        similarity(a.alias_norm, q_norm) as similarity_score
      FROM places p
      JOIN place_aliases a ON p.id = a.place_id
      WHERE similarity(a.alias_norm, q_norm) >= trigram_threshold
      ORDER BY similarity(a.alias_norm, q_norm) DESC, a.priority DESC, p.popularity DESC, p.name ASC
      LIMIT limit_n;

    END;
    $$ LANGUAGE plpgsql STABLE;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS search_places(text, int)"
  end
end
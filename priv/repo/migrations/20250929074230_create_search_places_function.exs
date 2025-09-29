defmodule RouteWiseApi.Repo.Migrations.CreateSearchPlacesFunction do
  use Ecto.Migration

  def up do
    # Create the main search function
    execute """
    CREATE OR REPLACE FUNCTION search_places(q_raw text, limit_n int DEFAULT 10)
    RETURNS TABLE (
      place_id int,
      name text,
      code text,
      kind text,
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
        p.name as matched_alias,
        'exact_canonical' as match_type,
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
        a.alias as matched_alias,
        'exact_alias' as match_type,
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
        p.name as matched_alias,
        'prefix_canonical' as match_type,
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
        a.alias as matched_alias,
        'prefix_alias' as match_type,
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
        p.name as matched_alias,
        'fuzzy_canonical' as match_type,
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
        a.alias as matched_alias,
        'fuzzy_alias' as match_type,
        similarity(a.alias_norm, q_norm) as similarity_score
      FROM places p
      JOIN place_aliases a ON p.id = a.place_id
      WHERE similarity(a.alias_norm, q_norm) >= trigram_threshold
      ORDER BY similarity(a.alias_norm, q_norm) DESC, a.priority DESC, p.popularity DESC, p.name ASC
      LIMIT limit_n;

    END;
    $$ LANGUAGE plpgsql STABLE;
    """

    # Create helper function for getting app settings with defaults
    execute """
    CREATE OR REPLACE FUNCTION get_search_setting(setting_name text, default_value text)
    RETURNS text AS $$
    BEGIN
      RETURN coalesce(
        nullif(current_setting('app.' || setting_name, true), ''),
        default_value
      );
    END;
    $$ LANGUAGE plpgsql STABLE;
    """

    # Create function to set search threshold (for testing/configuration)
    execute """
    CREATE OR REPLACE FUNCTION set_search_threshold(threshold real)
    RETURNS void AS $$
    BEGIN
      PERFORM set_config('app.search_similarity_threshold', threshold::text, false);
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS search_places(text, int)"
    execute "DROP FUNCTION IF EXISTS get_search_setting(text, text)"
    execute "DROP FUNCTION IF EXISTS set_search_threshold(real)"
  end
end
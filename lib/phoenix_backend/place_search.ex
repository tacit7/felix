defmodule RouteWiseApi.PlaceSearch do
  @moduledoc """
  Service layer for the places search system with aliases.

  Provides a clean interface for:
  - Query preprocessing and validation
  - SQL search function coordination
  - Result deduplication and ranking
  - Final result formatting and sorting

  Based on the Places Search POA implementation.
  """

  alias RouteWiseApi.Repo
  require Logger

  @doc """
  Search for places using the enhanced search system with aliases.

  ## Parameters
  - `query`: Search term (string)
  - `opts`: Options keyword list
    - `:limit` - Maximum results to return (default: 10, max: 100)
    - `:threshold` - Similarity threshold override (0.0-1.0)

  ## Returns
  `{:ok, results}` where results is a list of place maps with:
  - `:place_id` - Unique place identifier
  - `:name` - Canonical place name
  - `:code` - Place code (e.g., "USVI", "NYC")
  - `:kind` - Place type ("country", "region", "city", "poi")
  - `:coordinates` - `%{lat: float(), lng: float()}`
  - `:popularity` - Popularity score (integer)
  - `:metadata` - Additional place information
  - `:matched_alias` - The text that was matched
  - `:match_type` - Type of match ("exact_canonical", "exact_alias", etc.)
  - `:similarity_score` - Match confidence score (0.0-1.0)

  ## Examples
      iex> PlaceSearch.search("usvi")
      {:ok, [%{name: "United States Virgin Islands", matched_alias: "USVI", ...}]}

      iex> PlaceSearch.search("new yo", limit: 5)
      {:ok, [%{name: "New York City", matched_alias: "New York City", ...}]}
  """
  @spec search(String.t(), keyword()) :: {:ok, [map()]} | {:error, String.t()}
  def search(query, opts \\ []) when is_binary(query) do
    with {:ok, processed_query} <- preprocess_query(query),
         {:ok, limit} <- validate_limit(opts[:limit]),
         {:ok, threshold} <- validate_threshold(opts[:threshold]),
         {:ok, raw_results} <- execute_search(processed_query, limit, threshold),
         {:ok, formatted_results} <- format_results(raw_results) do
      final_results =
        formatted_results
        |> deduplicate_by_place_id()
        |> apply_final_ranking()
        |> Enum.take(limit)

      {:ok, final_results}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get search statistics and performance metrics.
  """
  @spec search_stats() :: map()
  def search_stats do
    {:ok, places_result} = Repo.query("SELECT COUNT(*) FROM places")
    {:ok, aliases_result} = Repo.query("SELECT COUNT(*) FROM place_aliases")
    {:ok, threshold_result} = Repo.query("SELECT current_setting('app.search_similarity_threshold', true)")

    [[places_count]] = places_result.rows
    [[aliases_count]] = aliases_result.rows
    [[current_threshold]] = threshold_result.rows

    %{
      places_count: places_count,
      aliases_count: aliases_count,
      current_threshold: parse_threshold(current_threshold),
      default_threshold: 0.35,
      supported_match_types: [
        "exact_canonical", "exact_alias",
        "prefix_canonical", "prefix_alias",
        "fuzzy_canonical", "fuzzy_alias"
      ]
    }
  end

  # Private implementation functions

  @spec preprocess_query(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp preprocess_query(query) when is_binary(query) do
    processed =
      query
      |> String.trim()
      |> collapse_whitespace()

    case String.length(processed) do
      0 -> {:error, "Query cannot be empty"}
      len when len < 2 -> {:error, "Query must be at least 2 characters"}
      _ -> {:ok, processed}
    end
  end

  @spec validate_limit(nil | integer()) :: {:ok, integer()}
  defp validate_limit(nil), do: {:ok, 10}
  defp validate_limit(limit) when is_integer(limit) and limit > 0 and limit <= 100, do: {:ok, limit}
  defp validate_limit(limit) when is_integer(limit) and limit > 100, do: {:ok, 100}
  defp validate_limit(_), do: {:ok, 10}

  @spec validate_threshold(nil | float()) :: {:ok, float() | nil}
  defp validate_threshold(nil), do: {:ok, nil}
  defp validate_threshold(threshold) when is_float(threshold) and threshold >= 0.0 and threshold <= 1.0 do
    {:ok, threshold}
  end
  defp validate_threshold(_), do: {:ok, nil}

  @spec execute_search(String.t(), integer(), float() | nil) :: {:ok, [map()]} | {:error, String.t()}
  defp execute_search(query, limit, threshold) do
    # Set threshold if provided
    if threshold do
      case Repo.query("SELECT set_search_threshold($1)", [threshold]) do
        {:ok, _} -> :ok
        {:error, reason} ->
          Logger.warning("Failed to set search threshold: #{inspect(reason)}")
      end
    end

    case Repo.query("SELECT * FROM search_places($1, $2)", [query, limit]) do
      {:ok, %{rows: rows, columns: columns}} ->
        results = Enum.map(rows, fn row ->
          columns
          |> Enum.zip(row)
          |> Enum.into(%{})
          |> convert_column_names()
        end)

        {:ok, results}

      {:error, reason} ->
        Logger.error("Search query failed: #{inspect(reason)}")
        {:error, "Search operation failed"}
    end
  rescue
    exception ->
      Logger.error("Search exception: #{Exception.message(exception)}")
      {:error, "Search operation failed"}
  end

  @spec format_results([map()]) :: {:ok, [map()]}
  defp format_results(raw_results) do
    formatted = Enum.map(raw_results, &format_single_result/1)
    {:ok, formatted}
  end

  @spec format_single_result(map()) :: map()
  defp format_single_result(raw_result) do
    %{
      place_id: raw_result["place_id"],
      name: raw_result["name"],
      code: raw_result["code"],
      kind: raw_result["kind"],
      coordinates: %{
        lat: parse_decimal(raw_result["latitude"]),
        lng: parse_decimal(raw_result["longitude"])
      },
      popularity: raw_result["popularity"],
      metadata: parse_json(raw_result["metadata"]) || %{},
      matched_alias: raw_result["matched_alias"],
      match_type: raw_result["match_type"],
      similarity_score: raw_result["similarity_score"]
    }
  end

  @spec deduplicate_by_place_id([map()]) :: [map()]
  defp deduplicate_by_place_id(results) do
    # Keep first occurrence of each place_id (highest priority match)
    results
    |> Enum.uniq_by(& &1.place_id)
  end

  @spec apply_final_ranking([map()]) :: [map()]
  defp apply_final_ranking(results) do
    results
    |> Enum.sort_by(fn result ->
      {
        # Primary: Similarity score (descending)
        -result.similarity_score,
        # Secondary: Match type priority (canonical over alias)
        match_type_priority(result.match_type),
        # Tertiary: Kind priority (country > region > city > poi)
        kind_priority(result.kind),
        # Quaternary: Popularity (descending)
        -result.popularity,
        # Final: Alphabetical by name for deterministic sort
        result.name
      }
    end)
  end

  @spec match_type_priority(String.t()) :: integer()
  defp match_type_priority("exact_canonical"), do: 1
  defp match_type_priority("exact_alias"), do: 2
  defp match_type_priority("prefix_canonical"), do: 3
  defp match_type_priority("prefix_alias"), do: 4
  defp match_type_priority("fuzzy_canonical"), do: 5
  defp match_type_priority("fuzzy_alias"), do: 6
  defp match_type_priority(_), do: 99

  @spec kind_priority(String.t()) :: integer()
  defp kind_priority("country"), do: 1
  defp kind_priority("region"), do: 2
  defp kind_priority("city"), do: 3
  defp kind_priority("poi"), do: 4
  defp kind_priority(_), do: 99

  # Helper functions

  @spec collapse_whitespace(String.t()) :: String.t()
  defp collapse_whitespace(text) do
    String.replace(text, ~r/\s+/, " ")
  end

  @spec convert_column_names(map()) :: map()
  defp convert_column_names(raw_result) do
    raw_result
    |> Enum.map(fn
      {"place_id", value} -> {"place_id", value}
      {"name", value} -> {"name", value}
      {"code", value} -> {"code", value}
      {"kind", value} -> {"kind", value}
      {"latitude", value} -> {"latitude", value}
      {"longitude", value} -> {"longitude", value}
      {"popularity", value} -> {"popularity", value}
      {"metadata", value} -> {"metadata", value}
      {"matched_alias", value} -> {"matched_alias", value}
      {"match_type", value} -> {"match_type", value}
      {"similarity_score", value} -> {"similarity_score", value}
      other -> other
    end)
    |> Enum.into(%{})
  end

  @spec parse_decimal(any()) :: float()
  defp parse_decimal(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp parse_decimal(value) when is_float(value), do: value
  defp parse_decimal(value) when is_integer(value), do: value * 1.0
  defp parse_decimal(value) when is_binary(value), do: String.to_float(value)
  defp parse_decimal(nil), do: 0.0
  defp parse_decimal(_), do: 0.0

  @spec parse_json(any()) :: map() | nil
  defp parse_json(value) when is_map(value), do: value
  defp parse_json(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end
  defp parse_json(_), do: nil

  @spec parse_threshold(String.t()) :: float()
  defp parse_threshold(""), do: 0.35
  defp parse_threshold(value) when is_binary(value) do
    case Float.parse(value) do
      {threshold, _} -> threshold
      :error -> 0.35
    end
  end
  defp parse_threshold(_), do: 0.35
end
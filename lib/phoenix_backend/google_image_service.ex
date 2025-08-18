defmodule RouteWiseApi.GoogleImageService do
  @moduledoc """
  Google Places Photo API integration with local caching and optimization.

  Downloads Google Places photos, caches them locally, and provides optimized
  serving through the existing ImageService infrastructure.

  ## Features

  - **Google Photos API**: Fetch photos from Google Places
  - **Local Caching**: Download and store images locally
  - **Size Optimization**: Multiple image sizes (thumb, medium, large)
  - **Format Conversion**: WebP conversion for better compression
  - **Batch Processing**: Efficient batch downloads
  - **Cache Management**: Automatic cleanup and TTL handling
  - **Fallback Support**: Integration with existing fallback system

  ## Usage

      # Fetch and cache single POI image
      {:ok, local_paths} = GoogleImageService.fetch_and_cache_poi_image(poi_id, google_place_id)

      # Batch process multiple POIs
      {:ok, results} = GoogleImageService.batch_fetch_poi_images([poi1, poi2, poi3])

      # Get cached image status
      status = GoogleImageService.get_cache_status(poi_id)

  ## Configuration

      # config/dev.exs
      config :phoenix_backend, RouteWiseApi.GoogleImageService,
        api_key: System.get_env("GOOGLE_PLACES_API_KEY"),
        max_width: 1600,
        cache_directory: "priv/static/images/pois",
        formats: [:webp, :jpg],
        batch_size: 10,
        rate_limit_ms: 100

  ## Directory Structure

      priv/static/images/pois/
      ├── 123/
      │   ├── original.jpg      # Original Google photo
      │   ├── thumb.webp        # 150x150 thumbnail
      │   ├── medium.webp       # 400x400 medium
      │   ├── large.webp        # 800x800 large
      │   └── xlarge.webp       # 1200x1200 extra large
      └── cache_metadata.json   # Cache tracking

  """

  require Logger

  @default_config %{
    api_key: nil,
    max_width: 1600,
    cache_directory: "priv/static/images/pois",
    formats: [:webp, :jpg],
    batch_size: 10,
    rate_limit_ms: 100,
    cache_ttl_days: 30,
    quality: 85
  }

  @size_variants %{
    thumb: 150,
    medium: 400, 
    large: 800,
    xlarge: 1200
  }

  @doc """
  Fetch and cache Google Places photo for a POI.

  ## Parameters
  - `poi_id`: Local POI identifier
  - `google_place_id`: Google Places API place ID
  - `photo_reference`: Optional specific photo reference
  - `opts`: Additional options

  ## Returns
  {:ok, %{original: path, variants: %{thumb: path, medium: path, ...}}}
  {:error, reason}

  ## Examples

      {:ok, paths} = GoogleImageService.fetch_and_cache_poi_image(
        123, 
        "ChIJ...", 
        photo_reference: "CmRa..."
      )

  """
  def fetch_and_cache_poi_image(poi_id, google_place_id, opts \\ []) do
    config = get_config()
    
    if config.api_key do
      Logger.info("🖼️  Fetching Google image for POI #{poi_id} (#{google_place_id})")

      with {:ok, photo_url} <- get_photo_url(google_place_id, opts),
           {:ok, image_data} <- download_image(photo_url),
           {:ok, local_paths} <- save_and_process_image(poi_id, image_data) do
        
        # Update cache metadata
        update_cache_metadata(poi_id, %{
          google_place_id: google_place_id,
          original_url: photo_url,
          cached_at: DateTime.utc_now(),
          file_size: byte_size(image_data),
          variants: Map.keys(local_paths.variants)
        })

        Logger.info("✅ Cached Google image for POI #{poi_id} - #{map_size(local_paths.variants)} variants")
        {:ok, local_paths}
      else
        {:error, reason} ->
          Logger.error("❌ Failed to cache Google image for POI #{poi_id}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, "Google Places API key not configured"}
    end
  end

  @doc """
  Batch fetch and cache images for multiple POIs.

  ## Parameters
  - `pois`: List of POI maps with :id and :google_place_id
  - `opts`: Batch processing options

  ## Returns
  {:ok, %{successful: [results], failed: [errors]}}

  ## Examples

      pois = [
        %{id: 1, google_place_id: "ChIJ..."},
        %{id: 2, google_place_id: "ChIJ..."}
      ]
      
      {:ok, results} = GoogleImageService.batch_fetch_poi_images(pois)

  """
  def batch_fetch_poi_images(pois, opts \\ []) do
    config = get_config()
    batch_size = Keyword.get(opts, :batch_size, config.batch_size)
    rate_limit = Keyword.get(opts, :rate_limit_ms, config.rate_limit_ms)

    Logger.info("🔄 Starting batch image fetch for #{length(pois)} POIs")

    results = pois
    |> Enum.chunk_every(batch_size)
    |> Enum.flat_map(fn batch ->
      batch_results = batch
      |> Task.async_stream(fn poi ->
        case fetch_and_cache_poi_image(poi.id, poi.google_place_id) do
          {:ok, paths} -> {:success, poi.id, paths}
          {:error, reason} -> {:error, poi.id, reason}
        end
      end, timeout: 30_000, max_concurrency: 3)
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, :timeout} -> {:error, :timeout, "Request timed out"}
      end)

      # Rate limiting between batches
      if rate_limit > 0, do: Process.sleep(rate_limit)
      
      batch_results
    end)

    {successful, failed} = Enum.split_with(results, fn
      {:success, _, _} -> true
      _ -> false
    end)

    Logger.info("✅ Batch complete: #{length(successful)} successful, #{length(failed)} failed")
    
    {:ok, %{
      successful: Enum.map(successful, fn {:success, id, paths} -> {id, paths} end),
      failed: Enum.map(failed, fn {:error, id, reason} -> {id, reason} end),
      stats: %{
        total: length(pois),
        successful_count: length(successful),
        failed_count: length(failed)
      }
    }}
  end

  @doc """
  Get Google Places photo URL.

  ## Parameters
  - `google_place_id`: Google Places API place ID
  - `opts`: Options including photo_reference, max_width

  ## Returns
  {:ok, photo_url} | {:error, reason}
  """
  def get_photo_url(google_place_id, opts \\ []) do
    config = get_config()
    
    # If photo_reference provided, use it directly
    if photo_reference = opts[:photo_reference] do
      photo_url = build_photo_url(photo_reference, opts)
      {:ok, photo_url}
    else
      # Fetch place details to get photo reference
      case fetch_place_photos(google_place_id) do
        {:ok, [photo | _]} ->
          photo_url = build_photo_url(photo["photo_reference"], opts)
          {:ok, photo_url}
        
        {:ok, []} ->
          {:error, "No photos available for place"}
        
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Check cache status for a POI.

  ## Parameters
  - `poi_id`: POI identifier

  ## Returns
  %{cached: boolean, variants: [sizes], cached_at: datetime, file_size: bytes}
  """
  def get_cache_status(poi_id) do
    poi_dir = build_poi_directory(poi_id)
    metadata_file = Path.join(poi_dir, "metadata.json")

    if File.exists?(metadata_file) do
      case File.read(metadata_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, metadata} ->
              variants = @size_variants
              |> Map.keys()
              |> Enum.filter(fn size ->
                file_path = Path.join(poi_dir, "#{size}.webp")
                File.exists?(file_path)
              end)

              Map.merge(metadata, %{
                "cached" => true,
                "variants_available" => variants,
                "cache_fresh" => cache_fresh?(metadata)
              })
            
            {:error, _} ->
              %{"cached" => false, "error" => "Invalid metadata"}
          end
        
        {:error, _} ->
          %{"cached" => false, "error" => "Cannot read metadata"}
      end
    else
      %{"cached" => false, "variants_available" => []}
    end
  end

  @doc """
  Clean up expired cache entries.

  ## Parameters
  - `opts`: Cleanup options

  ## Returns
  {:ok, %{cleaned: count, errors: [reasons]}}
  """
  def cleanup_expired_cache(opts \\ []) do
    config = get_config()
    dry_run = Keyword.get(opts, :dry_run, false)
    force_all = Keyword.get(opts, :force_all, false)

    base_dir = Path.join([:code.priv_dir(:phoenix_backend), "static", "images", "pois"])
    
    if File.dir?(base_dir) do
      {:ok, entries} = File.ls(base_dir)
      
      results = entries
      |> Enum.filter(&File.dir?(Path.join(base_dir, &1)))
      |> Enum.map(fn poi_id ->
        poi_dir = Path.join(base_dir, poi_id)
        metadata_file = Path.join(poi_dir, "metadata.json")
        
        should_clean = if force_all do
          true
        else
          case File.read(metadata_file) do
            {:ok, content} ->
              case Jason.decode(content) do
                {:ok, metadata} -> !cache_fresh?(metadata)
                {:error, _} -> true  # Invalid metadata, clean up
              end
            {:error, _} -> false  # No metadata, keep for now
          end
        end

        if should_clean and not dry_run do
          case File.rm_rf(poi_dir) do
            {:ok, _} -> {:cleaned, poi_id}
            {:error, reason, _} -> {:error, poi_id, reason}
          end
        else
          if should_clean do
            {:would_clean, poi_id}
          else
            {:kept, poi_id}
          end
        end
      end)

      cleaned = Enum.count(results, fn
        {:cleaned, _} -> true
        {:would_clean, _} -> dry_run
        _ -> false
      end)

      errors = Enum.filter(results, fn
        {:error, _, _} -> true
        _ -> false
      end)

      Logger.info("🧹 Cache cleanup: #{cleaned} entries cleaned, #{length(errors)} errors")
      {:ok, %{cleaned: cleaned, errors: errors, results: results}}
    else
      {:ok, %{cleaned: 0, errors: [], message: "Cache directory does not exist"}}
    end
  end

  @doc """
  Get service health and statistics.
  """
  def health_check do
    config = get_config()
    base_dir = Path.join([:code.priv_dir(:phoenix_backend), "static", "images", "pois"])
    
    stats = if File.dir?(base_dir) do
      {:ok, entries} = File.ls(base_dir)
      cached_pois = entries |> Enum.filter(&File.dir?(Path.join(base_dir, &1)))
      
      total_size = cached_pois
      |> Enum.map(fn poi_id ->
        poi_dir = Path.join(base_dir, poi_id)
        get_directory_size(poi_dir)
      end)
      |> Enum.sum()

      %{
        cached_pois: length(cached_pois),
        total_size_mb: Float.round(total_size / 1024 / 1024, 2),
        cache_directory: base_dir
      }
    else
      %{cached_pois: 0, total_size_mb: 0, cache_directory: base_dir, exists: false}
    end

    %{
      service: "GoogleImageService",
      status: if(config.api_key, do: "ready", else: "not_configured"),
      config: %{
        api_key_configured: !is_nil(config.api_key),
        max_width: config.max_width,
        formats: config.formats,
        cache_ttl_days: config.cache_ttl_days
      },
      cache: stats,
      supported_sizes: Map.keys(@size_variants)
    }
  end

  ## Private Functions

  defp get_config do
    app_config = Application.get_env(:phoenix_backend, __MODULE__, [])
    config_map = Enum.into(app_config, %{})
    
    Map.merge(@default_config, config_map)
  end

  defp fetch_place_photos(google_place_id) do
    config = get_config()
    
    url = "https://maps.googleapis.com/maps/api/place/details/json?" <>
          URI.encode_query(%{
            place_id: google_place_id,
            fields: "photos",
            key: config.api_key
          })

    case HTTPoison.get(url, [], timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"result" => %{"photos" => photos}}} -> {:ok, photos}
          {:ok, %{"result" => %{}}} -> {:ok, []}
          {:ok, %{"error_message" => error}} -> {:error, error}
          {:error, reason} -> {:error, "JSON decode error: #{inspect(reason)}"}
        end
      
      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, "HTTP #{status}: #{body}"}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp build_photo_url(photo_reference, opts) do
    config = get_config()
    max_width = Keyword.get(opts, :max_width, config.max_width)
    
    "https://maps.googleapis.com/maps/api/place/photo?" <>
    URI.encode_query(%{
      photoreference: photo_reference,
      maxwidth: max_width,
      key: config.api_key
    })
  end

  defp download_image(url) do
    Logger.debug("📥 Downloading image from: #{String.slice(url, 0, 100)}...")
    
    case HTTPoison.get(url, [], timeout: 30_000, follow_redirect: true) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "HTTP #{status} when downloading image"}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Download failed: #{inspect(reason)}"}
    end
  end

  defp save_and_process_image(poi_id, image_data) do
    poi_dir = build_poi_directory(poi_id)
    
    # Ensure directory exists
    case File.mkdir_p(poi_dir) do
      :ok ->
        # Save original image
        original_path = Path.join(poi_dir, "original.jpg")
        
        case File.write(original_path, image_data) do
          :ok ->
            # Generate size variants
            create_image_variants(poi_id, original_path)
          
          {:error, reason} ->
            {:error, "Failed to save original image: #{inspect(reason)}"}
        end
      
      {:error, reason} ->
        {:error, "Failed to create POI directory: #{inspect(reason)}"}
    end
  end

  defp create_image_variants(poi_id, original_path) do
    poi_dir = build_poi_directory(poi_id)
    
    variants = @size_variants
    |> Enum.map(fn {size_name, size_px} ->
      output_path = Path.join(poi_dir, "#{size_name}.webp")
      
      case convert_and_resize_image(original_path, output_path, size_px) do
        :ok -> {size_name, output_path}
        {:error, reason} ->
          Logger.warning("Failed to create #{size_name} variant: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.into(%{})

    if map_size(variants) > 0 do
      {:ok, %{
        original: original_path,
        variants: variants
      }}
    else
      {:error, "Failed to create any image variants"}
    end
  end

  defp convert_and_resize_image(input_path, output_path, size_px) do
    # Use ImageMagick/GraphicsMagick if available, otherwise skip conversion
    # This is a simplified version - in production you'd want proper image processing
    
    case System.cmd("convert", [
      input_path,
      "-resize", "#{size_px}x#{size_px}^",
      "-gravity", "center", 
      "-extent", "#{size_px}x#{size_px}",
      "-quality", "85",
      output_path
    ], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> 
        Logger.debug("ImageMagick not available or failed: #{error}")
        # Fallback: just copy the original file
        File.cp(input_path, output_path)
    end
  end

  defp build_poi_directory(poi_id) do
    Path.join([
      :code.priv_dir(:phoenix_backend),
      "static",
      "images", 
      "pois",
      to_string(poi_id)
    ])
  end

  defp update_cache_metadata(poi_id, metadata) do
    poi_dir = build_poi_directory(poi_id)
    metadata_file = Path.join(poi_dir, "metadata.json")
    
    metadata_json = Jason.encode!(metadata, pretty: true)
    File.write(metadata_file, metadata_json)
  end

  defp cache_fresh?(metadata) do
    config = get_config()
    
    case metadata["cached_at"] do
      nil -> false
      cached_at_str ->
        case DateTime.from_iso8601(cached_at_str) do
          {:ok, cached_at, _} ->
            age_days = DateTime.diff(DateTime.utc_now(), cached_at, :day)
            age_days < config.cache_ttl_days
          
          {:error, _} -> false
        end
    end
  end

  defp get_directory_size(dir_path) do
    case File.ls(dir_path) do
      {:ok, files} ->
        files
        |> Enum.map(fn file ->
          file_path = Path.join(dir_path, file)
          case File.stat(file_path) do
            {:ok, %{size: size}} -> size
            _ -> 0
          end
        end)
        |> Enum.sum()
      
      {:error, _} -> 0
    end
  end
end
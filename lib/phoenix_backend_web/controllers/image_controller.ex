defmodule RouteWiseApiWeb.ImageController do
  @moduledoc """
  Image serving controller with caching, optimization, and fallback support.

  Serves images from local filesystem with proper HTTP headers, caching,
  and intelligent fallback handling. Designed for development use with
  production-ready caching strategies.

  ## Features

  - **File System Serving**: Direct file serving from priv/static/images
  - **Cache Headers**: Proper ETags, Cache-Control, and Last-Modified
  - **Content Type Detection**: Automatic MIME type detection
  - **Fallback Images**: Automatic fallback for missing images
  - **Performance Optimized**: Efficient file reading and serving
  - **Error Handling**: Comprehensive error responses

  ## Supported Routes

  - `GET /api/images/pois/:poi_id/:size` - POI images
  - `GET /api/images/categories/:category` - Category icons
  - `GET /api/images/fallbacks/:type` - Fallback images
  - `GET /api/images/ui/:asset_type` - UI assets
  - `GET /api/images/*path` - Any custom image path

  ## Cache Strategy

  - **ETags**: File modification time + size based ETags
  - **Cache-Control**: 24-hour public caching
  - **304 Not Modified**: Efficient conditional requests
  - **Vary**: Proper header variations

  ## Error Handling

  - **404**: Missing images serve appropriate fallbacks
  - **500**: File system errors with proper logging
  - **400**: Invalid parameters with helpful messages
  """

  use RouteWiseApiWeb, :controller
  require Logger

  @image_extensions %{
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg", 
    ".png" => "image/png",
    ".webp" => "image/webp",
    ".svg" => "image/svg+xml",
    ".gif" => "image/gif"
  }

  @cache_max_age 86_400  # 24 hours
  @size_variants ["thumb", "medium", "large", "xlarge"]

  @doc """
  Serve POI images with size variants and fallback support.

  ## Route
  GET /api/images/pois/:poi_id/:size

  ## Parameters
  - `poi_id`: POI identifier
  - `size`: Image size (thumb, medium, large, xlarge)

  ## Query Parameters
  - `format`: Image format (webp, jpg, png) - defaults to webp

  ## Examples
  GET /api/images/pois/123/medium
  GET /api/images/pois/456/thumb?format=jpg
  """
  def poi_image(conn, %{"poi_id" => poi_id, "size" => size} = params) do
    unless size in @size_variants do
      return_error(conn, :bad_request, "Invalid size. Must be one of: #{Enum.join(@size_variants, ", ")}")
    else
      format = Map.get(params, "format", "webp")
      serve_image(conn, "pois/#{poi_id}/#{size}.#{format}", fallback: "fallbacks/poi-placeholder.#{format}")
    end
  end

  @doc """
  Serve category icons (SVG format).

  ## Route
  GET /api/images/categories/:category

  ## Parameters
  - `category`: Category name (restaurant, attraction, hotel, etc.)

  ## Query Parameters
  - `style`: Icon style (filled, outline, color) - defaults to filled

  ## Examples
  GET /api/images/categories/restaurant
  GET /api/images/categories/hotel?style=outline
  """
  def category_icon(conn, %{"category" => category} = params) do
    style = Map.get(params, "style", "filled")
    
    icon_filename = case style do
      "filled" -> "#{category}.svg"
      "outline" -> "#{category}-outline.svg" 
      "color" -> "#{category}-color.svg"
      _ -> "#{category}.svg"
    end

    serve_image(conn, "categories/#{icon_filename}", fallback: "fallbacks/default-icon.svg")
  end

  @doc """
  Serve fallback/placeholder images.

  ## Route
  GET /api/images/fallbacks/:type

  ## Examples
  GET /api/images/fallbacks/poi-placeholder.webp
  GET /api/images/fallbacks/restaurant-placeholder.jpg
  """
  def fallback_image(conn, %{"type" => type}) do
    serve_image(conn, "fallbacks/#{type}", fallback: "fallbacks/default-placeholder.webp")
  end

  @doc """
  Serve UI assets (logos, markers, icons).

  ## Route
  GET /api/images/ui/:asset_type

  ## Examples
  GET /api/images/ui/logo.svg
  GET /api/images/ui/marker-red.png
  """
  def ui_asset(conn, %{"asset_type" => asset_type}) do
    serve_image(conn, "ui/#{asset_type}", fallback: "fallbacks/default-icon.svg")
  end

  @doc """
  Serve any image from the images directory.

  ## Route
  GET /api/images/*path

  ## Examples
  GET /api/images/custom/hero-banner.jpg
  GET /api/images/temp/upload-123.png
  """
  def generic_image(conn, %{"path" => path}) when is_list(path) do
    image_path = Enum.join(path, "/")
    serve_image(conn, image_path, fallback: "fallbacks/default-placeholder.webp")
  end

  @doc """
  Get image service health and statistics.

  ## Route
  GET /api/images/health

  ## Response
  JSON with service status, configuration, and directory information.
  """
  def health_check(conn, _params) do
    health_info = RouteWiseApi.ImageService.health_check()
    
    # Add runtime statistics
    static_dir = Path.join([:code.priv_dir(:phoenix_backend), "static", "images"])
    stats = get_directory_stats(static_dir)
    
    response = Map.put(health_info, :statistics, stats)
    
    json(conn, response)
  end

  ## Private Functions

  defp serve_image(conn, image_path, opts \\ []) do
    full_path = build_image_path(image_path)
    
    case File.stat(full_path) do
      {:ok, %File.Stat{} = file_stat} ->
        # Check if client has cached version
        if fresh?(conn, file_stat) do
          send_resp(conn, 304, "")
        else
          case File.read(full_path) do
            {:ok, image_data} ->
              serve_image_data(conn, image_data, full_path, file_stat)
            
            {:error, reason} ->
              Logger.error("Failed to read image file #{full_path}: #{reason}")
              serve_fallback_or_error(conn, opts[:fallback])
          end
        end
      
      {:error, :enoent} ->
        Logger.debug("Image not found: #{full_path}")
        serve_fallback_or_error(conn, opts[:fallback])
      
      {:error, reason} ->
        Logger.error("File system error for #{full_path}: #{reason}")
        serve_fallback_or_error(conn, opts[:fallback])
    end
  end

  defp serve_image_data(conn, image_data, file_path, file_stat) do
    content_type = get_content_type(file_path)
    etag = generate_etag(file_stat)
    last_modified = format_http_date(file_stat.mtime)
    
    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("cache-control", "public, max-age=#{@cache_max_age}, immutable")
    |> put_resp_header("etag", etag)
    |> put_resp_header("last-modified", last_modified)
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("vary", "Accept-Encoding")
    |> send_resp(200, image_data)
  end

  defp serve_fallback_or_error(conn, nil) do
    return_error(conn, :not_found, "Image not found and no fallback available")
  end

  defp serve_fallback_or_error(conn, fallback_path) do
    Logger.debug("Serving fallback image: #{fallback_path}")
    serve_image(conn, fallback_path, fallback: nil)  # No nested fallbacks
  end

  defp build_image_path(relative_path) do
    Path.join([
      :code.priv_dir(:phoenix_backend),
      "static",
      "images", 
      relative_path
    ])
  end

  defp get_content_type(file_path) do
    extension = Path.extname(file_path) |> String.downcase()
    Map.get(@image_extensions, extension, "application/octet-stream")
  end

  defp fresh?(conn, file_stat) do
    client_etag = get_req_header(conn, "if-none-match") |> List.first()
    server_etag = generate_etag(file_stat)
    
    client_etag && client_etag == server_etag
  end

  defp generate_etag(%File.Stat{mtime: mtime, size: size}) do
    # Convert mtime to unix timestamp
    unix_time = mtime |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
    hash = :crypto.hash(:md5, "#{unix_time}-#{size}") |> Base.encode16(case: :lower)
    "\"#{String.slice(hash, 0, 16)}\""
  end

  defp format_http_date(naive_datetime) do
    naive_datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end

  defp return_error(conn, status, message) do
    status_code = case status do
      :bad_request -> 400
      :not_found -> 404
      :internal_server_error -> 500
      _ -> 500
    end

    conn
    |> put_status(status_code)
    |> json(%{
      error: Atom.to_string(status),
      message: message,
      timestamp: DateTime.utc_now()
    })
  end

  defp get_directory_stats(base_path) do
    if File.dir?(base_path) do
      try do
        {total_files, total_size} = count_files_recursive(base_path, 0, 0)
        
        %{
          total_files: total_files,
          total_size_bytes: total_size,
          total_size_mb: Float.round(total_size / 1024 / 1024, 2),
          base_path: base_path,
          subdirectories: count_subdirectories(base_path)
        }
      rescue
        error ->
          Logger.warning("Error getting directory stats: #{inspect(error)}")
          %{error: "Unable to get directory statistics"}
      end
    else
      %{
        total_files: 0,
        total_size_bytes: 0,
        base_path: base_path,
        exists: false
      }
    end
  end

  defp count_files_recursive(path, file_count, size_acc) do
    case File.ls(path) do
      {:ok, entries} ->
        Enum.reduce(entries, {file_count, size_acc}, fn entry, {files, size} ->
          full_path = Path.join(path, entry)
          
          case File.stat(full_path) do
            {:ok, %File.Stat{type: :regular, size: file_size}} ->
              {files + 1, size + file_size}
            
            {:ok, %File.Stat{type: :directory}} ->
              count_files_recursive(full_path, files, size)
            
            _ ->
              {files, size}
          end
        end)
      
      {:error, _} ->
        {file_count, size_acc}
    end
  end

  defp count_subdirectories(path) do
    case File.ls(path) do
      {:ok, entries} ->
        entries
        |> Enum.count(fn entry ->
          full_path = Path.join(path, entry)
          case File.stat(full_path) do
            {:ok, %File.Stat{type: :directory}} -> true
            _ -> false
          end
        end)
      
      {:error, _} -> 0
    end
  end
end
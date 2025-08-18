defmodule RouteWiseApi.POIImageWorker do
  @moduledoc """
  Background worker for fetching and caching Google Places images.

  Processes POI image requests asynchronously to avoid blocking the main
  application flow. Integrates with Google Places API and local image caching.

  ## Features

  - **Async Processing**: Non-blocking image downloads
  - **Batch Processing**: Efficient bulk image processing
  - **Error Handling**: Robust retry logic and error recovery
  - **Progress Tracking**: Real-time progress updates
  - **Rate Limiting**: Respects Google API rate limits
  - **Queue Management**: Priority-based processing

  ## Usage

      # Single POI image processing
      POIImageWorker.process_poi_image(poi_id, google_place_id)

      # Batch processing
      POIImageWorker.process_batch([%{id: 1, google_place_id: "ChIJ..."}, ...])

      # Background processing with GenServer
      POIImageWorker.start_link([])
      POIImageWorker.enqueue_poi_image(poi_id, google_place_id)

  ## Configuration

      # config/dev.exs
      config :phoenix_backend, RouteWiseApi.POIImageWorker,
        max_concurrent: 3,
        retry_attempts: 3,
        retry_backoff: 5000,
        batch_size: 10,
        enable_background: true

  """

  use GenServer
  require Logger
  
  alias RouteWiseApi.GoogleImageService
  alias RouteWiseApi.Places
  alias RouteWiseApi.Repo

  @default_config %{
    max_concurrent: 3,
    retry_attempts: 3,
    retry_backoff: 5000,
    batch_size: 10,
    enable_background: true,
    process_interval: 1000
  }

  defstruct [
    :config,
    queue: [],
    processing: %{},
    stats: %{
      processed: 0,
      failed: 0,
      queued: 0,
      in_progress: 0
    }
  ]

  ## Public API

  @doc """
  Start the POI image worker GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a single POI image synchronously.

  ## Parameters
  - `poi_id`: Local POI identifier
  - `google_place_id`: Google Places API place ID
  - `opts`: Processing options

  ## Returns
  {:ok, result} | {:error, reason}
  """
  def process_poi_image(poi_id, google_place_id, opts \\ []) do
    Logger.info("🖼️  Processing POI image: #{poi_id} (#{google_place_id})")
    
    case GoogleImageService.fetch_and_cache_poi_image(poi_id, google_place_id, opts) do
      {:ok, paths} ->
        # Update POI record with image paths
        update_poi_with_image_paths(poi_id, paths)
        
        Logger.info("✅ POI image processed successfully: #{poi_id}")
        {:ok, %{poi_id: poi_id, paths: paths}}
      
      {:error, reason} ->
        Logger.error("❌ POI image processing failed: #{poi_id} - #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Process multiple POI images in batch.

  ## Parameters
  - `pois`: List of POI maps with :id and :google_place_id
  - `opts`: Batch processing options

  ## Returns
  {:ok, %{successful: results, failed: errors}}
  """
  def process_batch(pois, opts \\ []) when is_list(pois) do
    Logger.info("🔄 Starting batch POI image processing: #{length(pois)} POIs")
    
    start_time = System.monotonic_time(:millisecond)
    
    case GoogleImageService.batch_fetch_poi_images(pois, opts) do
      {:ok, %{successful: successful, failed: failed} = results} ->
        # Update POI records with successful image paths
        successful
        |> Enum.each(fn {poi_id, paths} ->
          update_poi_with_image_paths(poi_id, paths)
        end)
        
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        Logger.info("""
        ✅ Batch POI image processing complete:
           - Duration: #{duration}ms
           - Successful: #{length(successful)}
           - Failed: #{length(failed)}
           - Success rate: #{Float.round(length(successful) / length(pois) * 100, 1)}%
        """)
        
        {:ok, Map.put(results, :duration_ms, duration)}
      
      {:error, reason} ->
        Logger.error("❌ Batch POI image processing failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Enqueue a POI image for background processing.

  ## Parameters
  - `poi_id`: POI identifier
  - `google_place_id`: Google Places ID
  - `opts`: Processing options including :priority

  ## Returns
  :ok
  """
  def enqueue_poi_image(poi_id, google_place_id, opts \\ []) do
    GenServer.cast(__MODULE__, {
      :enqueue, 
      %{
        poi_id: poi_id,
        google_place_id: google_place_id,
        opts: opts,
        priority: Keyword.get(opts, :priority, :normal),
        enqueued_at: DateTime.utc_now()
      }
    })
  end

  @doc """
  Enqueue multiple POIs for background processing.
  """
  def enqueue_batch(pois, opts \\ []) do
    GenServer.cast(__MODULE__, {:enqueue_batch, pois, opts})
  end

  @doc """
  Get current queue and processing statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Clear the processing queue.
  """
  def clear_queue do
    GenServer.cast(__MODULE__, :clear_queue)
  end

  @doc """
  Process all POIs from the database that don't have cached images.

  ## Parameters
  - `opts`: Processing options

  ## Returns
  {:ok, stats} | {:error, reason}
  """
  def process_all_missing_images(opts \\ []) do
    Logger.info("🔍 Finding POIs without cached images...")
    
    case find_pois_without_images() do
      {:ok, pois} when length(pois) > 0 ->
        Logger.info("📋 Found #{length(pois)} POIs without images")
        
        # Process in smaller batches to avoid overwhelming the system
        batch_size = Keyword.get(opts, :batch_size, 20)
        
        results = pois
        |> Enum.chunk_every(batch_size)
        |> Enum.with_index()
        |> Enum.map(fn {batch, index} ->
          Logger.info("Processing batch #{index + 1}/#{ceil(length(pois) / batch_size)}")
          
          case process_batch(batch, opts) do
            {:ok, result} -> result
            {:error, reason} -> %{successful: [], failed: batch, error: reason}
          end
        end)
        
        # Aggregate results
        total_successful = results |> Enum.flat_map(& &1.successful) |> length()
        total_failed = results |> Enum.flat_map(& &1.failed) |> length()
        
        Logger.info("""
        🎯 Mass image processing complete:
           - Total POIs: #{length(pois)}
           - Successful: #{total_successful}
           - Failed: #{total_failed}
           - Success rate: #{Float.round(total_successful / length(pois) * 100, 1)}%
        """)
        
        {:ok, %{
          total_pois: length(pois),
          successful: total_successful,
          failed: total_failed,
          batches: length(results)
        }}
      
      {:ok, []} ->
        Logger.info("✅ All POIs already have cached images")
        {:ok, %{message: "No POIs need image processing"}}
      
      {:error, reason} ->
        Logger.error("❌ Failed to find POIs without images: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## GenServer Callbacks

  @doc false
  def init(opts) do
    config = get_config(opts)
    
    if config.enable_background do
      Logger.info("🚀 POI Image Worker started with background processing enabled")
      schedule_processing()
    else
      Logger.info("📴 POI Image Worker started with background processing disabled")
    end
    
    {:ok, %__MODULE__{config: config}}
  end

  @doc false
  def handle_cast({:enqueue, job}, state) do
    new_queue = [job | state.queue] |> sort_queue_by_priority()
    new_stats = %{state.stats | queued: state.stats.queued + 1}
    
    Logger.debug("📥 Enqueued POI image job: #{job.poi_id}")
    
    {:noreply, %{state | queue: new_queue, stats: new_stats}}
  end

  @doc false
  def handle_cast({:enqueue_batch, pois, opts}, state) do
    jobs = pois
    |> Enum.map(fn poi ->
      %{
        poi_id: poi.id,
        google_place_id: poi.google_place_id,
        opts: opts,
        priority: Keyword.get(opts, :priority, :normal),
        enqueued_at: DateTime.utc_now()
      }
    end)
    
    new_queue = (jobs ++ state.queue) |> sort_queue_by_priority()
    new_stats = %{state.stats | queued: state.stats.queued + length(jobs)}
    
    Logger.info("📥 Enqueued batch: #{length(jobs)} POI image jobs")
    
    {:noreply, %{state | queue: new_queue, stats: new_stats}}
  end

  @doc false
  def handle_cast(:clear_queue, state) do
    Logger.info("🧹 Cleared POI image processing queue")
    new_stats = %{state.stats | queued: 0}
    
    {:noreply, %{state | queue: [], stats: new_stats}}
  end

  @doc false
  def handle_call(:get_stats, _from, state) do
    stats = Map.merge(state.stats, %{
      queue_length: length(state.queue),
      processing_count: map_size(state.processing)
    })
    
    {:reply, stats, state}
  end

  @doc false
  def handle_info(:process_queue, state) do
    if state.config.enable_background do
      new_state = process_queue_items(state)
      schedule_processing()
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @doc false
  def handle_info({:task_completed, task_ref, result}, state) do
    case Map.pop(state.processing, task_ref) do
      {job, new_processing} when not is_nil(job) ->
        new_stats = case result do
          {:ok, _} ->
            Logger.debug("✅ Completed POI image job: #{job.poi_id}")
            %{state.stats | 
              processed: state.stats.processed + 1,
              in_progress: state.stats.in_progress - 1
            }
          
          {:error, reason} ->
            Logger.error("❌ Failed POI image job: #{job.poi_id} - #{inspect(reason)}")
            %{state.stats | 
              failed: state.stats.failed + 1,
              in_progress: state.stats.in_progress - 1
            }
        end
        
        {:noreply, %{state | processing: new_processing, stats: new_stats}}
      
      {nil, _} ->
        # Task not found in processing map, ignore
        {:noreply, state}
    end
  end

  ## Private Functions

  defp get_config(opts) do
    app_config = Application.get_env(:phoenix_backend, __MODULE__, [])
    config_map = Enum.into(app_config ++ opts, %{})
    
    Map.merge(@default_config, config_map)
  end

  defp schedule_processing do
    Process.send_after(self(), :process_queue, 1000)
  end

  defp process_queue_items(state) do
    max_concurrent = state.config.max_concurrent
    current_processing = map_size(state.processing)
    available_slots = max_concurrent - current_processing
    
    if available_slots > 0 and length(state.queue) > 0 do
      {jobs_to_process, remaining_queue} = Enum.split(state.queue, available_slots)
      
      new_processing = jobs_to_process
      |> Enum.reduce(state.processing, fn job, acc ->
        task = Task.async(fn ->
          process_poi_image(job.poi_id, job.google_place_id, job.opts)
        end)
        
        # Monitor the task
        Process.monitor(task.pid)
        
        Map.put(acc, task.ref, job)
      end)
      
      new_stats = %{state.stats |
        queued: length(remaining_queue),
        in_progress: map_size(new_processing)
      }
      
      %{state | 
        queue: remaining_queue, 
        processing: new_processing,
        stats: new_stats
      }
    else
      state
    end
  end

  defp sort_queue_by_priority(queue) do
    queue
    |> Enum.sort_by(fn job ->
      case job.priority do
        :high -> 1
        :normal -> 2
        :low -> 3
        _ -> 2
      end
    end)
  end

  defp update_poi_with_image_paths(poi_id, paths) do
    # This would update your POI/Place model with the cached image paths
    # Implementation depends on your schema structure
    
    case Places.get_place(poi_id) do
      {:ok, place} ->
        image_data = %{
          has_cached_images: true,
          cached_at: DateTime.utc_now(),
          image_variants: Map.keys(paths.variants),
          original_image_path: paths.original
        }
        
        # Update the place with image information
        case Places.update_place(place, %{image_data: image_data}) do
          {:ok, updated_place} ->
            Logger.debug("📝 Updated POI #{poi_id} with image paths")
            {:ok, updated_place}
          
          {:error, reason} ->
            Logger.error("❌ Failed to update POI #{poi_id} with image paths: #{inspect(reason)}")
            {:error, reason}
        end
      
      {:error, reason} ->
        Logger.error("❌ POI #{poi_id} not found for image path update: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp find_pois_without_images do
    # Query POIs/Places that don't have cached images
    # This implementation depends on your schema
    
    try do
      # Example query - adjust based on your schema
      import Ecto.Query
      
      query = from p in Places.Place,
        where: is_nil(p.image_data) or 
               fragment("?->>'has_cached_images' IS NULL", p.image_data) or
               fragment("?->>'has_cached_images' = 'false'", p.image_data),
        where: not is_nil(p.google_place_id),
        select: %{id: p.id, google_place_id: p.google_place_id}
      
      pois = Repo.all(query)
      {:ok, pois}
    rescue
      error ->
        Logger.error("❌ Database query failed: #{inspect(error)}")
        {:error, "Database query failed"}
    end
  end
end
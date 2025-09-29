defmodule RouteWiseApi.BackgroundScraper do
  @moduledoc """
  Background scraping service for real-time place data collection.
  Scrapes TripAdvisor data when users search for places with no results.
  """
  
  use GenServer
  import Ecto.Query, warn: false
  require Logger
  alias RouteWiseApi.{Places, Repo}
  alias RouteWiseApi.Places.Place
  alias Phoenix.PubSub

  @scraper_path Path.join([File.cwd!(), "scraper", "universal_city_scraper.py"])
  @min_places_threshold 5
  @cache_duration_hours 24

  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def scrape_if_needed(city, state_or_country \\ "", user_id \\ nil) do
    GenServer.cast(__MODULE__, {:scrape_if_needed, city, state_or_country, user_id})
  end

  def get_scrape_status(job_id) do
    GenServer.call(__MODULE__, {:get_status, job_id})
  end

  # Server Implementation
  @impl true
  def init(_opts) do
    Logger.info("🚀 BackgroundScraper started")
    {:ok, %{
      running_jobs: %{},
      completed_jobs: %{},
      scrape_cache: %{}
    }}
  end

  @impl true
  def handle_cast({:scrape_if_needed, city, state_or_country, user_id}, state) do
    location_key = normalize_location(city, state_or_country)
    
    # Check if we need to scrape
    cond do
      # Already running for this location
      Map.has_key?(state.running_jobs, location_key) ->
        Logger.info("🔄 Scrape already running for #{location_key}")
        if user_id, do: notify_user(user_id, "scraping_in_progress", %{location: location_key})
        
      # Recently scraped (within cache duration)
      recently_scraped?(state.scrape_cache, location_key) ->
        Logger.info("📋 Recent scrape found for #{location_key}")
        if user_id, do: notify_user(user_id, "data_available", %{location: location_key})
        
      # Has sufficient data already
      has_sufficient_data?(city, state_or_country) ->
        Logger.info("✅ Sufficient data exists for #{location_key}")
        if user_id, do: notify_user(user_id, "data_available", %{location: location_key})
        
      # Need to scrape
      true ->
        Logger.info("🎯 Starting scrape for #{location_key}")
        job_id = start_scraping_job(city, state_or_country, user_id, location_key)
        
        new_state = put_in(state.running_jobs[location_key], %{
          job_id: job_id,
          user_id: user_id,
          started_at: DateTime.utc_now(),
          status: :running
        })
        
        if user_id, do: notify_user(user_id, "scraping_started", %{
          location: location_key, 
          job_id: job_id,
          estimated_time: "30-60 seconds"
        })
        
        {:noreply, new_state}
    end
    
    {:noreply, state}
  end

  @impl true
  def handle_call({:get_status, job_id}, _from, state) do
    status = find_job_status(state, job_id)
    {:reply, status, state}
  end

  @impl true
  def handle_info({:scrape_completed, location_key, result}, state) do
    Logger.info("✅ Scrape completed for #{location_key}")
    
    # Move job to completed
    job = state.running_jobs[location_key]
    
    completed_job = %{
      job
      | status: :completed,
        completed_at: DateTime.utc_now(),
        result: result
    }
    
    # Update state
    new_state = %{
      state
      | running_jobs: Map.delete(state.running_jobs, location_key),
        completed_jobs: Map.put(state.completed_jobs, location_key, completed_job),
        scrape_cache: Map.put(state.scrape_cache, location_key, DateTime.utc_now())
    }
    
    # Notify user
    if job.user_id do
      notify_user(job.user_id, "scraping_completed", %{
        location: location_key,
        places_found: result.total_places,
        restaurants: result.restaurants_count,
        attractions: result.attractions_count
      })
    end
    
    # Broadcast to all users searching this location
    Phoenix.PubSub.broadcast(
      RouteWiseApi.PubSub,
      "location:#{location_key}",
      {:new_places_available, result}
    )
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:scrape_failed, location_key, error}, state) do
    Logger.error("❌ Scrape failed for #{location_key}: #{inspect(error)}")
    
    job = state.running_jobs[location_key]
    
    # Update state
    new_state = %{
      state
      | running_jobs: Map.delete(state.running_jobs, location_key)
    }
    
    # Notify user of failure
    if job.user_id do
      notify_user(job.user_id, "scraping_failed", %{
        location: location_key,
        error: "Unable to gather place data at this time"
      })
    end
    
    {:noreply, new_state}
  end

  # Private Functions

  defp normalize_location(city, state_or_country) do
    location = if state_or_country != "", do: "#{city}, #{state_or_country}", else: city
    String.downcase(String.trim(location))
  end

  defp recently_scraped?(cache, location_key) do
    case Map.get(cache, location_key) do
      nil -> false
      scraped_at ->
        hours_ago = DateTime.diff(DateTime.utc_now(), scraped_at, :hour)
        hours_ago < @cache_duration_hours
    end
  end

  defp has_sufficient_data?(city, state_or_country) do
    query = from(p in Place, where: ilike(p.city, ^"%#{city}%"))
    
    query = if state_or_country != "" do
      from(p in query, where: ilike(p.state, ^"%#{state_or_country}%") or ilike(p.country, ^"%#{state_or_country}%"))
    else
      query
    end
    
    count = Repo.aggregate(query, :count, :id)
    count >= @min_places_threshold
  end

  defp start_scraping_job(city, state_or_country, user_id, location_key) do
    # Use Task.Supervisor for better process management
    task = Task.Supervisor.async_nolink(RouteWiseApi.TaskSupervisor, fn ->
      run_python_scraper(city, state_or_country, location_key)
    end)
    
    # Monitor the task
    spawn_link(fn ->
      case Task.await(task, :timer.minutes(5)) do  # 5 minute timeout
        {:ok, result} ->
          send(__MODULE__, {:scrape_completed, location_key, result})
        {:error, error} ->
          send(__MODULE__, {:scrape_failed, location_key, error})
      end
    end)
    
    task.ref
  end

  defp run_python_scraper(city, state_or_country, location_key) do
    Logger.info("🐍 Running Python scraper for #{location_key}")
    
    # Build command arguments for QUICK scrape (faster)
    args = ["python3", @scraper_path, city, "--type", "all"]
    args = if state_or_country != "", do: args ++ ["--state", state_or_country], else: args
    
    # Use quick scraper runner for speed
    quick_args = [
      "python3", 
      Path.join([File.cwd!(), "scraper", "scraper_runner.py"]),
      if(state_or_country != "", do: "#{city}, #{state_or_country}", else: city),
      "--quick"
    ]
    
    case System.cmd("python3", tl(quick_args), stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("✅ Python scraper completed for #{location_key}")
        
        # Parse the JSON output
        json_file = extract_json_filename(output)
        if json_file do
          import_and_return_results(json_file, location_key)
        else
          {:error, "No output file generated"}
        end
      
      {output, exit_code} ->
        Logger.error("❌ Python scraper failed for #{location_key} (exit: #{exit_code})")
        Logger.error("Output: #{output}")
        {:error, "Scraper failed with exit code #{exit_code}"}
    end
  end

  defp extract_json_filename(output) do
    output
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      if String.contains?(line, "Saved to:") do
        line |> String.split("Saved to:") |> List.last() |> String.trim()
      end
    end)
  end

  defp import_and_return_results(json_file, location_key) do
    case File.read(json_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} ->
            # Import to database
            {restaurants_imported, attractions_imported} = import_scraped_places(data)
            
            # Clean up file
            File.rm(json_file)
            
            # Return summary
            {:ok, %{
              location: location_key,
              total_places: restaurants_imported + attractions_imported,
              restaurants_count: restaurants_imported,
              attractions_count: attractions_imported,
              raw_data: data
            }}
            
          {:error, error} ->
            Logger.error("❌ JSON parse error for #{location_key}: #{inspect(error)}")
            {:error, "JSON parsing failed"}
        end
      
      {:error, error} ->
        Logger.error("❌ File read error for #{location_key}: #{inspect(error)}")
        {:error, "File reading failed"}
    end
  end

  defp import_scraped_places(data) do
    restaurants = Map.get(data, "restaurants", [])
    attractions = Map.get(data, "attractions", [])
    
    restaurants_imported = import_places_list(restaurants, "restaurant")
    attractions_imported = import_places_list(attractions, "tourist_attraction")
    
    Logger.info("📥 Imported #{restaurants_imported} restaurants, #{attractions_imported} attractions")
    
    {restaurants_imported, attractions_imported}
  end

  defp import_places_list(places_data, default_type) do
    Enum.count(places_data, fn place_data ->
      coords = Map.get(place_data, "coordinates", %{})
      lat = Map.get(coords, "lat")
      lng = Map.get(coords, "lng")
      
      if lat && lng do
        place_attrs = %{
          name: Map.get(place_data, "name"),
          google_place_id: "tripadvisor_" <> to_string(Map.get(place_data, "location_id", "")),
          latitude: lat,
          longitude: lng,
          address: Map.get(place_data, "address", ""),
          website: Map.get(place_data, "tripadvisor_url"),
          categories: [default_type],
          rating: 4.0,
          user_ratings_total: 100,
          business_status: "OPERATIONAL",
          data_source: "tripadvisor_scraper"
        }
        
        case Places.create_place(place_attrs) do
          {:ok, _place} ->
            true
          {:error, _changeset} ->
            false
        end
      else
        false
      end
    end)
  end

  defp notify_user(user_id, event_type, data) do
    Phoenix.PubSub.broadcast(
      RouteWiseApi.PubSub,
      "user:#{user_id}",
      {:scraping_update, event_type, data}
    )
  end

  defp find_job_status(state, job_id) do
    # Find job in running jobs
    running = Enum.find_value(state.running_jobs, fn {_key, job} ->
      if job.job_id == job_id, do: job
    end)
    
    if running do
      running
    else
      # Find in completed jobs
      Enum.find_value(state.completed_jobs, fn {_key, job} ->
        if job.job_id == job_id, do: job
      end)
    end
  end
end
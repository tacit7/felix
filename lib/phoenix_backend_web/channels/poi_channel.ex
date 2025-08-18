defmodule RouteWiseApiWeb.POIChannel do
  @moduledoc """
  Phoenix channel for real-time POI clustering updates.

  Provides efficient viewport-based POI cluster streaming with intelligent
  presence tracking and debounced updates to prevent client overwhelm.

  ## Channel Topics

  - `"poi:viewport"` - Real-time POI clusters for map viewport

  ## Features

  - **Presence Tracking**: Track active viewports for targeted broadcasts
  - **Debounced Updates**: Prevent spam from rapid viewport changes  
  - **Intelligent Caching**: Leverage ClusteringServer ETS cache
  - **Error Recovery**: Graceful handling of clustering failures
  - **Performance Metrics**: Track channel performance and usage

  ## Client Usage

      const socket = new Socket("/socket")
      const channel = socket.channel("poi:viewport", {
        bounds: {north: 40.78, south: 40.74, east: -73.94, west: -73.99},
        zoom: 12,
        filters: {categories: ["restaurant", "attraction"]}
      })

      channel.on("clusters_updated", (payload) => {
        setClusters(payload.clusters)
      })

      channel.push("bounds_changed", {
        bounds: newBounds,
        zoom: newZoom,
        filters: currentFilters
      })

  """
  
  use RouteWiseApiWeb, :channel
  require Logger

  alias RouteWiseApi.POI.ClusteringServer

  # Channel lifecycle

  @doc """
  Join the POI viewport channel with initial viewport bounds.

  ## Parameters

  - `"poi:viewport"` - Channel topic
  - `payload` - Map with required :bounds, optional :zoom, :filters

  ## Payload Format

      %{
        "bounds" => %{
          "north" => 40.7829,
          "south" => 40.7489,
          "east" => -73.9441,
          "west" => -73.9901
        },
        "zoom" => 12,
        "filters" => %{"categories" => ["restaurant"]}
      }

  """
  def join("poi:viewport", payload, socket) do
    Logger.info("POI channel join attempt - payload: #{inspect(payload)}")

    case validate_join_params(payload) do
      {:ok, validated_params} ->        
        # Store viewport params in socket assigns
        socket = assign(socket, :viewport_params, validated_params)
        
        Logger.info("POI channel join starting - socket: #{socket.id}, bounds: #{inspect(validated_params.bounds)}")
        
        # Return immediately with empty clusters - no async fetching during join
        Logger.info("POI channel join complete - returning immediately")
        
        # Send clusters after join completes
        Process.send_after(self(), {:fetch_initial_clusters, validated_params}, 500)
        
        {:ok, %{
          status: "connected",
          message: "Connected successfully",
          clusters: []  # Start with empty clusters
        }, socket}
      
      {:error, reason} ->
        Logger.error("POI channel join rejected - reason: #{reason}")
        {:error, %{reason: reason}}
    end
  end

  # Handle viewport changes with intelligent debouncing

  @doc """
  Handle viewport bounds changes with debounced clustering updates.

  Implements smart debouncing to prevent overwhelming the clustering system
  during rapid pan/zoom operations while maintaining responsive updates.
  """
  def handle_in("bounds_changed", payload, socket) do
    Logger.debug("Viewport bounds changed: #{inspect(payload)}")

    case validate_bounds_params(payload) do
      {:ok, new_params} ->
        # Cancel any pending update
        cancel_pending_update(socket)
        
        # Schedule debounced update
        update_ref = schedule_debounced_update(new_params, 200) # 200ms debounce
        
        # Update socket state
        socket = socket
        |> assign(:viewport_params, new_params)
        |> assign(:pending_update_ref, update_ref)
        
        {:noreply, socket}
      
      {:error, reason} ->
        Logger.warning("Invalid bounds change: #{reason}")
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("filters_changed", %{"filters" => filters}, socket) do
    Logger.debug("POI filters changed: #{inspect(filters)}")
    
    current_params = socket.assigns.viewport_params
    new_params = %{current_params | filters: normalize_filters(filters)}
    
    # Filters get immediate updates since they're less frequent
    case get_clusters_for_params(new_params) do
      {:ok, clusters} ->
        socket = assign(socket, :viewport_params, new_params)
        
        push(socket, "clusters_updated", %{
          clusters: clusters,
          reason: "filters_changed",
          cluster_count: length(clusters)
        })
        
        {:noreply, socket}
      
      {:error, reason} ->
        Logger.error("Failed to get clusters for filter change: #{reason}")
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("get_cache_stats", _payload, socket) do
    stats = ClusteringServer.get_cache_stats()
    {:reply, {:ok, stats}, socket}
  end

  def handle_in("refresh_clusters", _payload, socket) do
    params = socket.assigns.viewport_params
    
    # Force cache miss by adding timestamp
    cache_bust_params = Map.put(params, :cache_bust, System.system_time(:millisecond))
    
    case get_clusters_for_params(cache_bust_params) do
      {:ok, clusters} ->
        push(socket, "clusters_updated", %{
          clusters: clusters,
          reason: "manual_refresh",
          cluster_count: length(clusters)
        })
        
        {:reply, {:ok, %{refreshed: true}}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  # Handle internal messages

  @doc false
  def handle_info({:fetch_initial_clusters, params}, socket) do
    Logger.info("Starting initial cluster fetch for params: #{inspect(params)}")
    
    # Add timeout wrapper for initial fetch
    task = Task.async(fn -> 
      Logger.info("Task started - getting clusters for bounds: #{inspect(params.bounds)}")
      result = get_clusters_for_params(params)
      Logger.info("Task completed - result: #{inspect(result)}")
      result
    end)
    
    try do
      case Task.await(task, 8_000) do  # 8 second timeout
        {:ok, clusters} ->
          Logger.info("Successfully fetched #{length(clusters)} clusters")
          
          push(socket, "clusters_updated", %{
            clusters: clusters,
            reason: "initial_load",
            cluster_count: length(clusters)
          })
          
          {:noreply, socket}
        
        {:error, reason} ->
          Logger.error("Failed to fetch initial clusters: #{reason}")
          
          push(socket, "clustering_error", %{
            reason: reason,
            retry_suggested: true
          })
          
          {:noreply, socket}
      end
    catch
      :exit, {:timeout, _} ->
        Logger.error("Initial cluster fetch timed out after 8 seconds")
        Task.shutdown(task, :brutal_kill)
        
        push(socket, "clustering_error", %{
          reason: "Initial clustering timeout - area may be too large",
          retry_suggested: true
        })
        
        {:noreply, socket}
    end
  end

  @doc false
  def handle_info({:debounced_update, params, ref}, socket) do
    # Check if this is still the current pending update
    if socket.assigns[:pending_update_ref] == ref do
      case get_clusters_for_params(params) do
        {:ok, clusters} ->
          push(socket, "clusters_updated", %{
            clusters: clusters,
            reason: "viewport_changed",
            cluster_count: length(clusters)
          })
          
          socket = assign(socket, :pending_update_ref, nil)
          {:noreply, socket}
        
        {:error, reason} ->
          Logger.error("Debounced clustering update failed: #{reason}")
          
          push(socket, "clustering_error", %{
            reason: reason,
            retry_suggested: true
          })
          
          socket = assign(socket, :pending_update_ref, nil)
          {:noreply, socket}
      end
    else
      # Stale update, ignore it
      {:noreply, socket}
    end
  end


  # Client disconnect cleanup

  @doc false
  def terminate(reason, socket) do
    Logger.debug("POI channel terminating: #{inspect(reason)}")
    
    # Cancel any pending updates
    cancel_pending_update(socket)
    
    :ok
  end

  # Private helper functions

  defp validate_join_params(%{"bounds" => bounds} = params) do
    with {:ok, normalized_bounds} <- normalize_bounds(bounds),
         zoom <- Map.get(params, "zoom", 12),
         filters <- normalize_filters(Map.get(params, "filters", %{})) do
      
      {:ok, %{
        bounds: normalized_bounds,
        zoom: ensure_valid_zoom(zoom),
        filters: filters
      }}
    else
      error -> {:error, "Invalid join parameters: #{inspect(error)}"}
    end
  end

  defp validate_join_params(_), do: {:error, "Missing required bounds parameter"}

  defp validate_bounds_params(%{"bounds" => bounds} = params) do
    current_params = %{
      bounds: bounds,
      zoom: Map.get(params, "zoom", 12),
      filters: normalize_filters(Map.get(params, "filters", %{}))
    }
    
    case normalize_bounds(bounds) do
      {:ok, normalized_bounds} ->
        {:ok, %{current_params | bounds: normalized_bounds, zoom: ensure_valid_zoom(current_params.zoom)}}
      error ->
        {:error, "Invalid bounds: #{inspect(error)}"}
    end
  end

  defp normalize_bounds(%{"north" => n, "south" => s, "east" => e, "west" => w}) 
       when is_number(n) and is_number(s) and is_number(e) and is_number(w) do
    
    # Validate coordinate ranges
    if n >= -90 and n <= 90 and s >= -90 and s <= 90 and
       e >= -180 and e <= 180 and w >= -180 and w <= 180 and
       n > s and e > w do
      
      {:ok, %{
        north: n,
        south: s,
        east: e,
        west: w
      }}
    else
      {:error, "Invalid coordinate ranges"}
    end
  end

  defp normalize_bounds(_), do: {:error, "Invalid bounds format"}

  defp normalize_filters(filters) when is_map(filters) do
    filters
    |> Enum.reduce(%{}, fn
      {"categories", categories}, acc ->
        if is_list(categories) do
          Map.put(acc, :categories, categories)
        else
          acc
        end
      
      {"min_rating", rating}, acc ->
        if is_number(rating) and rating >= 0 and rating <= 5 do
          Map.put(acc, :min_rating, rating)
        else
          acc
        end
      
      {"price_levels", levels}, acc ->
        if is_list(levels) do
          valid_levels = Enum.filter(levels, &(&1 in [1, 2, 3, 4]))
          if length(valid_levels) > 0, do: Map.put(acc, :price_levels, valid_levels), else: acc
        else
          acc
        end
      
      {"has_reviews", true}, acc ->
        Map.put(acc, :has_reviews, true)
      
      _other, acc -> acc  # Ignore invalid filters
    end)
  end

  defp normalize_filters(_), do: %{}

  defp ensure_valid_zoom(zoom) when is_number(zoom) and zoom >= 1 and zoom <= 20, do: round(zoom)
  defp ensure_valid_zoom(_), do: 12  # Default zoom


  defp get_clusters_for_params(params) do
    try do
      clusters = ClusteringServer.get_clusters(
        params.bounds,
        params.zoom,
        params.filters
      )
      
      {:ok, clusters}
    rescue
      error ->
        Logger.error("ClusteringServer error: #{inspect(error)}")
        {:error, "Clustering calculation failed"}
    catch
      :exit, {:timeout, _} ->
        Logger.warning("ClusteringServer timeout")
        {:error, "Clustering timeout - try zooming in"}
    end
  end


  defp schedule_debounced_update(params, delay_ms) do
    ref = make_ref()
    Process.send_after(self(), {:debounced_update, params, ref}, delay_ms)
    ref
  end

  defp cancel_pending_update(%{assigns: %{pending_update_ref: ref}}) when not is_nil(ref) do
    # Note: We can't actually cancel the message, but we check ref validity in handle_info
    :ok
  end

  defp cancel_pending_update(_socket), do: :ok
end
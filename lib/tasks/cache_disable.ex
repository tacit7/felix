defmodule Mix.Tasks.Cache.Disable do
  @moduledoc """
  Disable caching system for debugging.
  
  Updates the development configuration to use the disabled backend,
  which returns cache misses for all operations.
  
  ## Usage
      mix cache.disable
  """
  
  use Mix.Task
  require Logger
  
  @shortdoc "Disable caching system for debugging"
  
  def run([]) do
    config_path = "config/dev.exs"
    
    if File.exists?(config_path) do
      update_config(config_path)
    else
      IO.puts("❌ Config file not found: #{config_path}")
      exit(:error)
    end
  end
  
  defp update_config(config_path) do
    content = File.read!(config_path)
    
    # Pattern to match the caching configuration
    old_pattern = ~r/config :phoenix_backend, RouteWiseApi\.Caching,\s*\n\s*backend:\s*RouteWiseApi\.Caching\.Backend\.\w+,/
    
    new_config = "config :phoenix_backend, RouteWiseApi.Caching,\n  backend: RouteWiseApi.Caching.Backend.Disabled,"
    
    if Regex.match?(old_pattern, content) do
      updated_content = Regex.replace(old_pattern, content, new_config)
      
      # Also update TTL multiplier for consistency
      ttl_pattern = ~r/ttl_multiplier:\s*[\d.]+/
      final_content = Regex.replace(ttl_pattern, updated_content, "ttl_multiplier: 0.0")
      
      File.write!(config_path, final_content)
      
      IO.puts("✅ Caching disabled successfully")
      IO.puts("   - Backend: RouteWiseApi.Caching.Backend.Disabled")
      IO.puts("   - TTL Multiplier: 0.0")
      IO.puts("   - All cache operations will return cache misses")
      IO.puts("")
      IO.puts("📝 Note: Restart your server for changes to take effect")
      IO.puts("   mix phx.server")
    else
      IO.puts("❌ Could not find caching configuration to disable")
      IO.puts("   Please check config/dev.exs manually")
    end
  end
end
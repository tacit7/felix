defmodule Mix.Tasks.Cache.Enable do
  @moduledoc """
  Enable caching system for normal operation.
  
  Updates the development configuration to use the memory backend
  with standard development TTL multipliers.
  
  ## Usage
      mix cache.enable
  """
  
  use Mix.Task
  require Logger
  
  @shortdoc "Enable caching system for normal operation"
  
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
    
    new_config = "config :phoenix_backend, RouteWiseApi.Caching,\n  backend: RouteWiseApi.Caching.Backend.Memory,"
    
    if Regex.match?(old_pattern, content) do
      updated_content = Regex.replace(old_pattern, content, new_config)
      
      # Update TTL multiplier for development
      ttl_pattern = ~r/ttl_multiplier:\s*[\d.]+/
      final_content = Regex.replace(ttl_pattern, updated_content, "ttl_multiplier: 0.1")
      
      File.write!(config_path, final_content)
      
      IO.puts("✅ Caching enabled successfully")
      IO.puts("   - Backend: RouteWiseApi.Caching.Backend.Memory")
      IO.puts("   - TTL Multiplier: 0.1 (10% of normal TTLs for dev)")
      IO.puts("   - Cache operations will work normally")
      IO.puts("")
      IO.puts("📝 Note: Restart your server for changes to take effect")
      IO.puts("   mix phx.server")
    else
      IO.puts("❌ Could not find caching configuration to enable")
      IO.puts("   Please check config/dev.exs manually")
    end
  end
end
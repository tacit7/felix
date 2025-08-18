defmodule RouteWiseApi.Assert do
  @moduledoc """
  Assertion macros for catching developer mistakes early.
  
  These are compiled out in production for zero runtime overhead.
  """
  
  @assertions Application.compile_env(:phoenix_backend, :assertions, false)

  defmacro assert!(cond, msg \\ "assertion failed") do
    if @assertions do
      quote do
        unless unquote(cond), do: raise(RuntimeError, unquote(msg))
      end
    else
      quote(do: :ok)
    end
  end

  defmacro pre!(cond, msg \\ "precondition failed") do
    quote(do: RouteWiseApi.Assert.assert!(unquote(cond), unquote(msg)))
  end

  defmacro post!(cond, msg \\ "postcondition failed") do
    quote(do: RouteWiseApi.Assert.assert!(unquote(cond), unquote(msg)))
  end
end
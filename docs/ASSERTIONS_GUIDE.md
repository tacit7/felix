# Assertions Guide

Assertions are **developer tripwires**: small checks inside the code that validate assumptions about inputs, outputs, and invariants. They are not error handling, and they are not user-facing. If an assertion fails, it means **our code is wrong**.

---

## When to Use Assertions

- **Preconditions**  
  Check that inputs to a function or module meet required constraints.  
  Example:  
  ```elixir
  pre!(order.status == :pending, "order must be pending")
  ```

- **Postconditions**  
  Verify that a function produced the expected result before returning.  
  Example:  
  ```elixir
  post!(balance >= 0, "balance cannot be negative")
  ```

- **Invariants**  
  Enforce rules that must always hold true during runtime.  
  Example:  
  ```elixir
  assert!(Enum.uniq(user_roles) == user_roles, "duplicate roles not allowed")
  ```

---

## When *Not* to Use Assertions

- Do **not** replace user-facing error handling.  
  Timeouts, bad input, or external API failures need proper error handling.  
- Do **not** rescue assertion failures in production.  
  If they fire, the system is in a broken state—fix the code.  
- Do **not** litter every line with assertions.  
  Focus on important invariants, not trivialities.

---

## Build Modes

- **Development / Test:**  
  Assertions are enabled. Fail fast and loudly.  
- **Production:**  
  Assertions are compiled out or reduced to no-ops. There is no runtime overhead.  

We use a compile-time flag in `config/*.exs` to control this.  

---

## Implementation Pattern

We use macros to avoid runtime cost:

```elixir
# config/dev.exs, config/test.exs
config :my_app, assertions: true

# config/prod.exs
config :my_app, assertions: false
```

```elixir
defmodule MyApp.Assert do
  @assertions Application.compile_env(:my_app, :assertions, false)

  defmacro assert!(cond, msg \\ "assertion failed") do
    if @assertions do
      quote do
        unless unquote(cond), do: raise(RuntimeError, unquote(msg))
      end
    else
      quote(do: :ok)
    end
  end

  defmacro pre!(cond, msg \\ "precondition failed"),  do: quote(do: MyApp.Assert.assert!(unquote(cond), unquote(msg)))
  defmacro post!(cond, msg \\ "postcondition failed"), do: quote(do: MyApp.Assert.assert!(unquote(cond), unquote(msg)))
end
```

---

## Guidelines

1. **Assertions are for developers, not users.** If it fails, we fix the code.  
2. **Keep them cheap.** Boolean checks only. No heavy DB calls or I/O.  
3. **Target critical paths.** Use them in service modules, domain logic, and transitions—where a bad assumption causes corruption.  
4. **Prefer function guards first.** Let Elixir’s pattern matching enforce simple contracts. Use assertions for the rest.  
5. **Document intent.** Every assertion should tell a future reader *why* the condition must hold.  

---

## Example: Trip State Transition

```elixir
def transition(%Trip{status: from} = trip, to) do
  pre!(to in allowed_transitions(from), "illegal transition: #{from} → #{to}")

  updated =
    trip
    |> Trip.changeset(%{status: to})
    |> Repo.update!()

  post!(updated.status == to, "transition did not persist")

  updated
end
```

---

## Takeaway

Assertions are **cheap contracts** we write with ourselves.  
They help us catch lies early in development and keep production clean.  
Use them for **safety**, not as a substitute for **error handling**.

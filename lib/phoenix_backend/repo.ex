defmodule RouteWiseApi.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_backend,
    adapter: Ecto.Adapters.Postgres
end

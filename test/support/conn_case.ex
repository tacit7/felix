defmodule RouteWiseApiWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use RouteWiseApiWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint RouteWiseApiWeb.Endpoint

      use RouteWiseApiWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import RouteWiseApiWeb.ConnCase
    end
  end

  setup tags do
    RouteWiseApi.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that logs in a user for authenticated tests.
  """
  def log_in_user(conn, user) do
    {:ok, token, _claims} = RouteWiseApi.Guardian.encode_and_sign(user)
    
    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")
    |> Plug.Test.put_req_cookie("auth_token", token)
  end
end

defmodule RouteWiseApiWeb.AuthErrorHandler do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    body = 
      case type do
        :invalid_token -> %{error: "Invalid authentication token"}
        :token_expired -> %{error: "Authentication token has expired"}
        :no_resource_found -> %{error: "User not found"}
        :already_authenticated -> %{error: "Already authenticated"}
        :not_authenticated -> %{error: "Authentication required"}
        _ -> %{error: "Authentication failed"}
      end

    status = 
      case type do
        :not_authenticated -> :unauthorized
        :invalid_token -> :unauthorized
        :token_expired -> :unauthorized
        :no_resource_found -> :unauthorized
        :already_authenticated -> :forbidden
        _ -> :unauthorized
      end

    conn
    |> put_status(status)
    |> json(body)
  end
end
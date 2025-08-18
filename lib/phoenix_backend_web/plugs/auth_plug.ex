defmodule RouteWiseApiWeb.Plugs.AuthPlug do
  @moduledoc """
  Authentication plugs for handling JWT tokens and user authentication.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias RouteWiseApi.Guardian

  def init(opts), do: opts

  def call(conn, :verify_cookie_token), do: verify_cookie_token(conn, [])
  def call(conn, :authenticate_user), do: authenticate_user(conn, [])
  def call(conn, :maybe_authenticate_user), do: maybe_authenticate_user(conn, [])
  def call(conn, opts), do: authenticate_user(conn, opts)

  @doc """
  Ensures that a valid JWT token is present in the request.
  Adds the current user to the connection assigns.
  """
  def authenticate_user(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()

      user ->
        assign(conn, :current_user, user)
    end
  end

  @doc """
  Optional authentication - adds user to conn if token is valid,
  but doesn't halt if no token is present.
  """
  def maybe_authenticate_user(conn, _opts) do
    case Guardian.Plug.current_resource(conn) do
      nil -> conn
      user -> assign(conn, :current_user, user)
    end
  end

  @doc """
  Ensures the current user owns the resource specified by the user_id parameter.
  """
  def ensure_owner(conn, _opts) do
    current_user = conn.assigns[:current_user]
    user_id = conn.params["user_id"] || conn.params["id"]

    if current_user && current_user.id == user_id do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Access denied"})
      |> halt()
    end
  end

  @doc """
  Rate limiting plug for authentication endpoints.
  """
  def rate_limit_auth(conn, _opts) do
    # Simple rate limiting - in production, use a proper rate limiting library
    # like Hammer or ExRated, or implement Redis-based rate limiting
    conn
  end

  @doc """
  Validates authentication input (username/password format).
  """
  def validate_auth_params(conn, _opts) do
    case conn.params do
      %{"username" => username, "password" => password} when is_binary(username) and is_binary(password) ->
        if String.length(username) >= 3 and String.length(password) >= 6 do
          conn
        else
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Username must be at least 3 characters and password at least 6 characters"})
          |> halt()
        end

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Username and password are required"})
        |> halt()
    end
  end

  @doc """
  Adds security headers to authentication responses.
  """
  def add_security_headers(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
  end

  @doc """
  Custom cookie authentication plug to manually verify JWT tokens from cookies.
  """
  def verify_cookie_token(conn, _opts) do
    with token when is_binary(token) <- get_token_from_cookie(conn),
         {:ok, claims} <- RouteWiseApi.Guardian.decode_and_verify(token),
         {:ok, user} <- RouteWiseApi.Guardian.resource_from_claims(claims) do
      conn
      |> Guardian.Plug.put_current_token(token)
      |> Guardian.Plug.put_current_claims(claims)
      |> Guardian.Plug.put_current_resource(user)
    else
      _error ->
        conn
    end
  end

  defp get_token_from_cookie(conn) do
    case conn.req_cookies do
      %{"auth_token" => token} -> token
      _ -> nil
    end
  end
end
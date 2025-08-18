defmodule RouteWiseApiWeb.Plugs.UnifiedAuth do
  @moduledoc """
  Unified authentication plug that handles both Phoenix Guardian tokens
  and Express.js JWT tokens for cross-system compatibility.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.debug("UnifiedAuth: Processing request to #{conn.request_path}")
    Logger.debug("UnifiedAuth: Headers: #{inspect(get_req_header(conn, "authorization"))}")
    Logger.debug("UnifiedAuth: Cookies: #{inspect(Map.get(conn.cookies, "auth_token"))}")
    
    with {:ok, token} <- extract_token(conn),
         {:ok, user} <- verify_token(token) do
      Logger.debug("UnifiedAuth: Successfully authenticated user #{user.id}")
      conn
      |> assign(:current_user, user)
      |> assign(:auth_token, token)
    else
      {:error, reason} ->
        Logger.debug("Authentication failed: #{inspect(reason)}")
        conn
        |> assign(:current_user, nil)
        |> assign(:auth_token, nil)
    end
  end

  @doc """
  Require authentication - returns 401 if user not authenticated
  """
  def require_auth(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: %{message: "Authentication required", code: "AUTH_REQUIRED"}})
        |> halt()
      _user ->
        conn
    end
  end

  # Private functions

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> extract_token_from_cookie(conn)
    end
  end

  defp extract_token_from_cookie(conn) do
    case Map.get(conn.cookies, "auth_token") do
      nil -> {:error, :no_token}
      token -> {:ok, token}
    end
  end

  defp verify_token(token) do
    case verify_phoenix_token(token) do
      {:ok, user} -> {:ok, user}
      {:error, _reason} -> verify_express_token(token)
    end
  end

  defp verify_phoenix_token(token) do
    Logger.debug("UnifiedAuth: Verifying Phoenix token")
    case RouteWiseApi.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        Logger.debug("UnifiedAuth: Phoenix token decoded successfully")
        case RouteWiseApi.Guardian.resource_from_claims(claims) do
          {:ok, user} -> 
            Logger.debug("UnifiedAuth: User resolved from Phoenix token: #{user.id}")
            {:ok, user}
          {:error, reason} -> 
            Logger.debug("UnifiedAuth: Failed to resolve user from Phoenix token: #{inspect(reason)}")
            {:error, {:guardian_resource, reason}}
        end
      {:error, reason} ->
        Logger.debug("UnifiedAuth: Failed to decode Phoenix token: #{inspect(reason)}")
        {:error, {:guardian_decode, reason}}
    end
  end

  defp verify_express_token(token) do
    # Basic JWT verification for Express.js tokens
    # In production, this should verify the signature with shared secret
    case decode_jwt_payload(token) do
      {:ok, payload} ->
        case get_user_from_express_payload(payload) do
          {:ok, user} -> {:ok, user}
          {:error, reason} -> {:error, {:express_user, reason}}
        end
      {:error, reason} ->
        {:error, {:express_decode, reason}}
    end
  end

  defp decode_jwt_payload(token) do
    case String.split(token, ".") do
      [_header, payload, _signature] ->
        try do
          decoded = Base.url_decode64!(payload, padding: false)
          case Jason.decode(decoded) do
            {:ok, data} -> {:ok, data}
            {:error, _} -> {:error, :json_decode}
          end
        rescue
          _ -> {:error, :base64_decode}
        end
      _ ->
        {:error, :invalid_format}
    end
  end

  defp get_user_from_express_payload(%{"id" => _user_id, "email" => email} = payload) do
    # Try to find existing user by email or create minimal user record
    case RouteWiseApi.Accounts.get_user_by_email(email) do
      nil ->
        # Create minimal user record for Express.js users
        create_minimal_user_from_express(payload)
      user ->
        {:ok, user}
    end
  end

  defp get_user_from_express_payload(_), do: {:error, :invalid_payload}

  defp create_minimal_user_from_express(payload) do
    user_params = %{
      email: payload["email"],
      username: payload["username"] || payload["email"],
      full_name: payload["name"] || payload["fullName"],
      provider: "express",
      password_hash: nil  # Express.js managed user
    }

    case RouteWiseApi.Accounts.create_user(user_params) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} ->
        Logger.warning("Failed to create Express.js user: #{inspect(changeset.errors)}")
        {:error, :user_creation_failed}
    end
  end
end
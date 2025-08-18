# DEPRECATED: This module is no longer used
# We now use server-side OAuth via Ueberauth instead of client-side JWT verification

defmodule RouteWiseApi.GoogleJWTVerifier do
  @moduledoc """
  DEPRECATED: Module for verifying Google JWT tokens from frontend OAuth flow.
  
  This module is no longer used as we've switched to server-side OAuth via Ueberauth.
  Kept for reference but should not be used in production.
  """
  
  require Logger
  
  @google_certs_url "https://www.googleapis.com/oauth2/v3/certs"
  @google_issuer "https://accounts.google.com"
  @cache_key "google_jwt_certs"
  @cache_ttl 3600  # 1 hour
  
  @doc """
  Verify a Google JWT ID token and extract user information.
  
  ## Parameters
  - `token` - The Google ID token string from frontend OAuth
  - `client_id` - Your Google OAuth client ID (optional, uses env var if not provided)
  
  ## Returns
  - `{:ok, user_info}` - Success with user data map
  - `{:error, reason}` - Verification failed
  
  ## Example
  ```elixir
  case GoogleJWTVerifier.verify_token(google_token) do
    {:ok, user_info} ->
      # user_info contains: sub, email, name, given_name, family_name, picture
      create_user_from_google(user_info)
    {:error, :invalid_token} ->
      {:error, "Invalid Google token"}
  end
  ```
  """
  @spec verify_token(String.t(), String.t() | nil) :: {:ok, map()} | {:error, atom()}
  def verify_token(token, client_id \\ nil) do
    client_id = client_id || get_client_id()
    
    with {:ok, header, payload} <- decode_token(token),
         {:ok, public_key} <- get_public_key(header["kid"]),
         :ok <- verify_signature(token, public_key),
         :ok <- verify_claims(payload, client_id) do
      {:ok, extract_user_info(payload)}
    else
      {:error, reason} -> 
        Logger.warning("Google JWT verification failed: #{inspect(reason)}")
        {:error, reason}
      error -> 
        Logger.warning("Google JWT verification error: #{inspect(error)}")
        {:error, :verification_failed}
    end
  end
  
  @doc """
  Extract user information from verified Google JWT payload.
  """
  @spec extract_user_info(map()) :: map()
  def extract_user_info(payload) do
    %{
      sub: payload["sub"],
      email: payload["email"],
      email_verified: payload["email_verified"],
      name: payload["name"],
      given_name: payload["given_name"],
      family_name: payload["family_name"],
      picture: payload["picture"],
      locale: payload["locale"]
    }
  end
  
  # Private functions
  
  defp decode_token(token) do
    case String.split(token, ".") do
      [header_b64, payload_b64, _signature_b64] ->
        with {:ok, header_json} <- Base.url_decode64(header_b64, padding: false),
             {:ok, payload_json} <- Base.url_decode64(payload_b64, padding: false),
             {:ok, header} <- Jason.decode(header_json),
             {:ok, payload} <- Jason.decode(payload_json) do
          {:ok, header, payload}
        else
          _ -> {:error, :invalid_token_format}
        end
      _ ->
        {:error, :invalid_token_format}
    end
  end
  
  defp get_public_key(kid) when is_binary(kid) do
    case get_google_certs() do
      {:ok, certs} ->
        case Map.get(certs, kid) do
          nil -> {:error, :key_not_found}
          cert_data -> build_public_key(cert_data)
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp get_public_key(_), do: {:error, :invalid_key_id}
  
  defp get_google_certs do
    # Try to get from cache first
    case get_cached_certs() do
      {:ok, certs} -> {:ok, certs}
      :error -> fetch_and_cache_certs()
    end
  end
  
  defp get_cached_certs do
    # Simple in-memory cache using process dictionary for now
    # In production, you'd use ETS, Redis, or your existing cache system
    case Process.get(@cache_key) do
      {certs, expires_at} ->
        now = :os.system_time(:second)
        if expires_at > now do
          {:ok, certs}
        else
          :error
        end
      _ ->
        :error
    end
  end
  
  defp fetch_and_cache_certs do
    case HTTPoison.get(@google_certs_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"keys" => keys}} ->
            # Convert list of keys to map keyed by kid
            certs = Enum.into(keys, %{}, fn key -> {key["kid"], key} end)
            
            # Cache for 1 hour
            expires_at = :os.system_time(:second) + @cache_ttl
            Process.put(@cache_key, {certs, expires_at})
            
            {:ok, certs}
          _ ->
            {:error, :invalid_certs_response}
        end
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, {:network_error, reason}}
    end
  end
  
  defp build_public_key(%{"kty" => "RSA", "n" => n, "e" => e}) do
    try do
      # Decode base64url components
      {:ok, n_binary} = Base.url_decode64(n, padding: false)
      {:ok, e_binary} = Base.url_decode64(e, padding: false)
      
      # Build RSA public key
      rsa_key = :public_key.der_encode(:RSAPublicKey, {
        :RSAPublicKey,
        :binary.decode_unsigned(n_binary),
        :binary.decode_unsigned(e_binary)
      })
      
      {:ok, {:RSAPublicKey, rsa_key}}
    rescue
      _ -> {:error, :invalid_key_format}
    end
  end
  
  defp build_public_key(_), do: {:error, :unsupported_key_type}
  
  defp verify_signature(token, {_type, public_key}) do
    case JOSE.JWT.verify(public_key, token) do
      {true, _payload, _jws} -> :ok
      {false, _payload, _jws} -> {:error, :invalid_signature}
      _ -> {:error, :signature_verification_failed}
    end
  end
  
  defp verify_claims(payload, client_id) do
    now = :os.system_time(:second)
    
    with :ok <- verify_issuer(payload["iss"]),
         :ok <- verify_audience(payload["aud"], client_id),
         :ok <- verify_expiration(payload["exp"], now),
         :ok <- verify_issued_at(payload["iat"], now) do
      :ok
    end
  end
  
  defp verify_issuer(@google_issuer), do: :ok
  defp verify_issuer("accounts.google.com"), do: :ok  # Alternative issuer format
  defp verify_issuer(_), do: {:error, :invalid_issuer}
  
  defp verify_audience(aud, client_id) when is_list(aud) do
    if client_id in aud, do: :ok, else: {:error, :invalid_audience}
  end
  
  defp verify_audience(aud, client_id) when is_binary(aud) do
    if aud == client_id, do: :ok, else: {:error, :invalid_audience}
  end
  
  defp verify_audience(_, _), do: {:error, :invalid_audience}
  
  defp verify_expiration(exp, now) when is_integer(exp) and exp > now, do: :ok
  defp verify_expiration(_, _), do: {:error, :token_expired}
  
  defp verify_issued_at(iat, now) when is_integer(iat) and iat <= now + 60, do: :ok  # Allow 1 minute clock skew
  defp verify_issued_at(_, _), do: {:error, :invalid_issued_at}
  
  defp get_client_id do
    case System.get_env("GOOGLE_CLIENT_ID") do
      nil -> 
        Logger.error("GOOGLE_CLIENT_ID environment variable not set")
        nil
      client_id -> client_id
    end
  end
end
defmodule RouteWiseApiWeb.AuthController do
  use RouteWiseApiWeb, :controller

  alias RouteWiseApi.Accounts
  alias RouteWiseApi.Guardian
  require Logger
  # alias RouteWiseApiWeb.Plugs.AuthPlug

  action_fallback(RouteWiseApiWeb.FallbackController)

  # plug :add_security_headers
  # plug :rate_limit_auth when action in [:login, :register]
  # plug :validate_auth_params when action in [:login, :register]

  @doc """
  POST /api/auth/register
  Register a new user account
  """
  def register(conn, %{"username" => username, "password" => password} = params) do
    user_params = %{
      username: username,
      password: password,
      email: params["email"],
      full_name: params["full_name"]
    }

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        IO.inspect(user, label: "User created successfully")

        case Guardian.encode_and_sign(user) do
          {:ok, token, _claims} ->
            IO.inspect("SUCCESS: Guardian token generated")
            IO.inspect(token, label: "Setting auth_token cookie with token")
            IO.inspect(conn.scheme, label: "Connection scheme")

            conn
            |> put_status(:created)
            |> put_resp_cookie("auth_token", token,
              http_only: true,
              secure: conn.scheme == :https,
              same_site: "Strict",
              # 7 days
              max_age: 7 * 24 * 60 * 60
            )
            |> json(%{
              success: true,
              message: "Account created successfully",
              user: user_response(user),
              token: token
            })

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to generate authentication token"})
        end

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "Registration failed",
          errors: format_changeset_errors(changeset)
        })
    end
  end

  @doc """
  POST /api/auth/login
  Authenticate user with username and password
  """
  def login(conn, %{"username" => username, "password" => password}) do
    case Accounts.authenticate_user(username, password) do
      {:ok, user} ->
        case Guardian.encode_and_sign(user) do
          {:ok, token, _claims} ->
            conn
            |> put_resp_cookie("auth_token", token,
              http_only: true,
              secure: conn.scheme == :https,
              same_site: "Strict",
              # 7 days
              max_age: 7 * 24 * 60 * 60
            )
            |> json(%{
              success: true,
              message: "Login successful",
              user: user_response(user),
              token: token
            })

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to generate authentication token"})
        end

      {:error, :invalid_username} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid username or password"})

      {:error, :invalid_password} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid username or password"})
    end
  end

  @doc """
  POST /api/auth/logout
  Logout user (clear cookie)
  """
  def logout(conn, _params) do
    conn
    |> delete_resp_cookie("auth_token")
    |> json(%{
      success: true,
      message: "Logged out successfully"
    })
  end

  # Removed Google JWT verification - using server-side OAuth only

  @doc """
  GET /api/auth/me
  Get current user information (requires authentication)
  """
  def me(conn, _params) do
    case conn.assigns[:current_user] do
      %Accounts.User{} = user ->
        json(conn, %{
          success: true,
          user: user_response(user)
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          success: false,
          error: %{
            message: "Authentication required",
            code: "AUTH_REQUIRED"
          }
        })
    end
  end

  @doc """
  GET /api/auth/google
  Initiate Google OAuth flow - redirect to Ueberauth endpoint
  """
  def google_auth(conn, _params) do
    redirect(conn, to: "/auth/google")
  end

  @doc """
  GET /auth/google
  Ueberauth request phase - initiates Google OAuth flow
  """
  def request(conn, _params) do
    Logger.info("🚀 AuthController.request/2 - OAuth initiation started")
    Logger.info("📍 Function: request/2")
    Logger.info("🔗 URL: /auth/google")
    Logger.info("📊 Connection details: #{inspect(%{
      method: conn.method,
      path_info: conn.path_info,
      query_string: conn.query_string,
      host: conn.host,
      port: conn.port,
      scheme: conn.scheme
    })}")
    
    # This initiates OAuth flow - handled by Ueberauth plug
    Logger.info("✅ AuthController.request/2 - Passing to Ueberauth plug")
    conn
  end

  @doc """
  GET /auth/google/callback
  Handle Google OAuth callback - this is called by Ueberauth after OAuth flow
  """
  def callback(conn, _params) do
    Logger.info("🎯 AuthController.callback/2 - OAuth callback received")
    Logger.info("📍 Function: callback/2")
    Logger.info("🔗 URL: /auth/google/callback")
    Logger.info("📊 Connection details: #{inspect(%{
      method: conn.method,
      path_info: conn.path_info,
      query_string: conn.query_string,
      host: conn.host,
      port: conn.port,
      scheme: conn.scheme
    })}")
    Logger.info("🎫 Ueberauth auth present: #{conn.assigns[:ueberauth_auth] != nil}")
    
    case conn.assigns[:ueberauth_auth] do
      %Ueberauth.Auth{} = auth ->
        Logger.info("✅ AuthController.callback/2 - Ueberauth.Auth received successfully")
        Logger.info("👤 Google user email: #{auth.info.email}")
        Logger.info("🆔 Google user UID: #{auth.uid}")
        Logger.info("📸 Profile image: #{auth.info.image}")

        google_user_info = %{
          "sub" => auth.uid,
          "email" => auth.info.email,
          "given_name" => auth.info.first_name || "",
          "family_name" => auth.info.last_name || "",
          "picture" => auth.info.image
        }
        
        Logger.info("📋 Google user info compiled: #{inspect(google_user_info)}")

        case Accounts.find_or_create_user_from_google(google_user_info) do
          {:ok, user} ->
            Logger.info("🎉 AuthController.callback/2 - User created/found successfully")
            Logger.info("👤 User ID: #{user.id}, Email: #{user.email}")

            case Guardian.encode_and_sign(user) do
              {:ok, token, _claims} ->
                Logger.info("🔐 AuthController.callback/2 - JWT token generated successfully")
                Logger.info("🍪 Setting auth_token cookie...")
                Logger.info("🏠 Frontend URL: #{frontend_url()}")
                redirect_url = "#{frontend_url()}/auth/success?token=#{token}"
                Logger.info("🔀 Redirecting to: #{redirect_url}")

                conn
                |> put_resp_cookie("auth_token", token,
                  http_only: true,
                  secure: conn.scheme == :https,
                  # Changed from Strict to Lax for cross-site redirects
                  same_site: "Lax",
                  max_age: 7 * 24 * 60 * 60
                )
                |> redirect(external: redirect_url)

              {:error, reason} ->
                Logger.error("❌ AuthController.callback/2 - Failed to generate JWT token")
                Logger.error("🔍 JWT Error reason: #{inspect(reason)}")
                redirect(conn, external: "#{frontend_url()}/auth/error?reason=jwt_failed")
            end

          {:error, changeset} ->
            Logger.error("❌ AuthController.callback/2 - Failed to create/find user")
            Logger.error("🔍 User creation error: #{inspect(changeset)}")
            redirect(conn, external: "#{frontend_url()}/auth/error?reason=user_failed")
        end

      %Ueberauth.Failure{errors: errors} ->
        Logger.error("❌ AuthController.callback/2 - Google OAuth failed")
        Logger.error("🔍 OAuth errors: #{inspect(errors)}")
        redirect(conn, external: "#{frontend_url()}/auth/error?reason=oauth_failed")

      _ ->
        Logger.error("❌ AuthController.callback/2 - Unknown OAuth callback state")
        Logger.error("🔍 Auth assign: #{inspect(conn.assigns[:ueberauth_auth])}")
        redirect(conn, external: "#{frontend_url()}/auth/error?reason=unknown")
    end
  end

  @doc """
  GET /auth/success - Fallback for OAuth success redirects that shouldn't hit backend
  This indicates the frontend isn't running or doesn't have the /auth/success route
  """
  def oauth_success_fallback(conn, params) do
    Logger.warning("🚨 AuthController.oauth_success_fallback/2 - This shouldn't happen!")
    Logger.warning("📍 Function: oauth_success_fallback/2")
    Logger.warning("🔗 URL: /auth/success")
    Logger.info("📊 Connection details: #{inspect(%{
      method: conn.method,
      path_info: conn.path_info,
      query_string: conn.query_string,
      host: conn.host,
      port: conn.port,
      scheme: conn.scheme
    })}")
    Logger.info("📋 Params received: #{inspect(params)}")
    Logger.info("🏠 Frontend should be running on: #{frontend_url()}")

    token = params["token"]
    Logger.info("🎫 Token in params: #{token != nil}")

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, """
    <html>
      <head><title>OAuth Success - Frontend Missing</title></head>
      <body style="font-family: Arial, sans-serif; margin: 40px;">
        <h1>✅ OAuth Authentication Successful!</h1>
        <p><strong>Issue:</strong> This request should have gone to your frontend, not the backend.</p>

        <h3>🔧 To Fix:</h3>
        <ol>
          <li>Make sure your frontend is running on: <code>#{frontend_url()}</code></li>
          <li>Create an <code>/auth/success</code> route in your frontend</li>
          <li>The route should handle the token: <code>#{token}</code></li>
        </ol>

        <h3>📋 Frontend Implementation:</h3>
        <pre style="background: #f5f5f5; padding: 15px; border-radius: 5px;">
    // pages/auth/success.jsx
    export default function AuthSuccess() {
    useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search)
    const token = urlParams.get('token')

    if (token) {
      // Token is also in HTTP-only cookie
      // Redirect to dashboard
      window.location.href = '/dashboard'
    }
    }, [])

    return <div>Login successful! Redirecting...</div>
    }
        </pre>

        <p><a href="#{frontend_url()}">← Go to Frontend</a></p>
      </body>
    </html>
    """)
  end

  @doc """
  GET /auth/error - Fallback for OAuth error redirects that shouldn't hit backend
  """
  def oauth_error_fallback(conn, params) do
    Logger.warning("OAuth error redirect hit backend instead of frontend!")
    Logger.info("Params: #{inspect(params)}")

    reason = params["reason"] || "unknown"

    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, """
    <html>
      <head><title>OAuth Error - Frontend Missing</title></head>
      <body style="font-family: Arial, sans-serif; margin: 40px;">
        <h1>❌ OAuth Authentication Failed</h1>
        <p><strong>Error:</strong> #{reason}</p>
        <p><strong>Issue:</strong> This request should have gone to your frontend, not the backend.</p>

        <h3>🔧 To Fix:</h3>
        <ol>
          <li>Make sure your frontend is running on: <code>#{frontend_url()}</code></li>
          <li>Create an <code>/auth/error</code> route in your frontend</li>
        </ol>

        <p><a href="#{frontend_url()}">← Go to Frontend</a></p>
        <p><a href="/api/auth/google">🔄 Try OAuth Again</a></p>
      </body>
    </html>
    """)
  end

  # Plug functions (commented out - will be implemented when AuthPlug module is created)

  # defp add_security_headers(conn, _opts) do
  #   AuthPlug.add_security_headers(conn, [])
  # end

  # defp rate_limit_auth(conn, _opts) do
  #   AuthPlug.rate_limit_auth(conn, [])
  # end

  # defp validate_auth_params(conn, _opts) do
  #   AuthPlug.validate_auth_params(conn, [])
  # end

  # Private helper functions

  defp user_response(user) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      full_name: user.full_name,
      avatar: user.avatar,
      provider: user.provider,
      created_at: user.inserted_at
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc """
  POST /api/auth/mock
  Mock authentication for development only (creates/logs in test user)
  """
  def mock_auth(conn, _params) do
    if Mix.env() != :dev do
      conn
      |> put_status(:not_found)
      |> json(%{error: "Endpoint not available"})
    else
      # Create or find mock user
      mock_user_params = %{
        username: "testuser",
        password: "password123",
        email: "test@example.com",
        full_name: "Test User"
      }

      user = case Accounts.get_user_by_username("testuser") do
        nil ->
          case Accounts.register_user(mock_user_params) do
            {:ok, user} -> user
            {:error, _} -> 
              # User might exist with different constraints, try to get by email
              Accounts.get_user_by_email("test@example.com")
          end
        existing_user -> existing_user
      end

      if user do
        case Guardian.encode_and_sign(user) do
          {:ok, token, _claims} ->
            conn
            |> put_resp_cookie("auth_token", token,
              http_only: true,
              secure: false,  # Development only
              same_site: "Lax",
              max_age: 7 * 24 * 60 * 60
            )
            |> json(%{
              success: true,
              message: "Mock authentication successful",
              user: user_response(user),
              token: token
            })

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Failed to generate authentication token"})
        end
      else
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to create mock user"})
      end
    end
  end

  defp frontend_url do
    "http://localhost:3001"
  end
end

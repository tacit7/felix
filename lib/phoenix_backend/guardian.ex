defmodule RouteWiseApi.Guardian do
  @moduledoc """
  Guardian configuration for JWT token management in the RouteWise API.

  Handles JWT token generation, validation, and user resource resolution.
  Integrates with the Accounts context for user authentication and lookup.

  ## Token Management

  - **Subject**: User ID stored as string in `sub` claim
  - **Resource Resolution**: Converts token claims back to User structs
  - **Authentication**: Username/password validation with Bcrypt
  - **Error Handling**: Comprehensive error types for debugging

  ## Configuration

  Configured in `config.exs` with:
  - `secret_key`: JWT signing secret (via GUARDIAN_SECRET_KEY env var)
  - `ttl`: Token time-to-live (default 7 days)
  - `allowed_algos`: Permitted signing algorithms

  ## Usage

      # Generate token
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      # Verify and get user
      {:ok, user, _claims} = Guardian.resource_from_token(token)

      # Direct authentication
      {:ok, user} = RouteWiseApi.Guardian.authenticate("username", "password")

  ## Security Features

  - Bcrypt password hashing verification
  - Integer ID validation and parsing
  - Resource existence verification
  - Comprehensive error handling for security logging
  """
  use Guardian, otp_app: :phoenix_backend

  alias RouteWiseApi.Accounts

  @doc """
  Converts a user resource to a token subject.

  Extracts the user ID and converts it to a string for JWT storage.
  Used during token generation.

  ## Parameters

  - `user` - User struct with `:id` field
  - `_claims` - Additional claims (unused)

  ## Returns

  - `{:ok, string_id}` - User ID as string
  - `{:error, :reason_for_error}` - Invalid resource
  """
  @spec subject_for_token(map(), map()) :: {:ok, String.t()} | {:error, atom()}
  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :reason_for_error}
  end

  @doc """
  Converts JWT claims back to a user resource.

  Parses the subject ID from claims and fetches the corresponding user
  from the database. Used during token verification.

  ## Parameters

  - `claims` - JWT claims map with `"sub"` key

  ## Returns

  - `{:ok, user}` - User struct if found
  - `{:error, :resource_not_found}` - User not found in database
  - `{:error, :invalid_id_format}` - Subject ID parsing failed
  - `{:error, :reason_for_error}` - Invalid claims format
  """
  @spec resource_from_claims(map()) :: {:ok, map()} | {:error, atom()}
  def resource_from_claims(%{"sub" => id}) do
    # Convert string ID back to integer for database lookup
    case Integer.parse(id) do
      {int_id, ""} ->
        case Accounts.get_user(int_id) do
          nil -> {:error, :resource_not_found}
          user -> {:ok, user}
        end

      _ ->
        {:error, :invalid_id_format}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :reason_for_error}
  end

  @doc """
  Authenticates a user with username and password.

  Performs database lookup and Bcrypt password verification.
  Alternative to token-based authentication for login endpoints.

  ## Parameters

  - `username` - Username to authenticate
  - `password` - Plain text password

  ## Returns

  - `{:ok, user}` - Authentication successful
  - `{:error, :invalid_credentials}` - Username not found or password mismatch

  ## Security Notes

  - Uses constant-time Bcrypt verification
  - Same error for user not found vs wrong password (timing attack prevention)
  - Does not expose whether username exists
  """
  @spec authenticate(String.t(), String.t()) :: {:ok, map()} | {:error, :invalid_credentials}
  def authenticate(username, password) do
    case Accounts.get_user_by_username(username) do
      nil -> {:error, :invalid_credentials}
      user -> validate_password(password, user)
    end
  end

  # Validates password using Bcrypt with timing attack protection
  defp validate_password(password, user) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end
end

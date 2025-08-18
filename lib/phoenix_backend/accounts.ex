defmodule RouteWiseApi.Accounts do
  @moduledoc """
  The Accounts context for user management and authentication.

  Provides comprehensive user account operations including registration,
  authentication, profile management, and OAuth integration. Follows Phoenix
  context patterns with clear boundaries and error handling.

  ## Core Features

  - **Local Authentication**: Username/password registration and login
  - **Google OAuth**: OAuth2 integration with account linking
  - **JWT Token Management**: Session token generation and validation
  - **Profile Management**: User profile updates and data management
  - **Security**: Bcrypt password hashing and timing attack prevention

  ## User Lookup Functions

  Multiple user lookup methods for flexibility:
  - `get_user/1` - By ID (soft lookup)
  - `get_user!/1` - By ID (raises on not found)
  - `get_user_by_username/1` - By username
  - `get_user_by_email/1` - By email address
  - `get_user_by_google_id/1` - By Google OAuth ID

  ## Authentication Flow

  ### Local Authentication
      # Register new user
      {:ok, user} = Accounts.register_user(%{
        username: "john_doe",
        email: "john@example.com",
        password: "secure123"
      })

      # Authenticate
      {:ok, user} = Accounts.authenticate_user("john_doe", "secure123")

      # Generate JWT token
      {:ok, token, _claims} = Accounts.generate_user_session_token(user)

  ### OAuth Authentication
      # Google OAuth callback
      {:ok, user} = Accounts.find_or_create_user_from_google(google_user_info)

  ## Data Validation

  User data is validated through Ecto changesets:
  - **Username**: 3-30 chars, alphanumeric + underscores, unique
  - **Email**: Valid format, unique
  - **Password**: Minimum 8 chars, complexity requirements
  - **Provider**: "local" or "google"

  ## Security Considerations

  - Passwords hashed with Bcrypt (cost 12)
  - Timing attack prevention with `Bcrypt.no_user_verify/0`
  - JWT tokens with configurable TTL
  - OAuth account linking with existing email validation
  """

  import Ecto.Query, warn: false
  alias RouteWiseApi.Repo

  alias RouteWiseApi.Accounts.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!("invalid")
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user.

  Returns nil if the User does not exist.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user("invalid")
      nil

  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by username.

  ## Examples

      iex> get_user_by_username("john_doe")
      %User{}

      iex> get_user_by_username("nonexistent")
      nil

  """
  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("john@example.com")
      %User{}

      iex> get_user_by_email("nonexistent@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by Google ID.

  ## Examples

      iex> get_user_by_google_id("123456789")
      %User{}

      iex> get_user_by_google_id("nonexistent")
      nil

  """
  def get_user_by_google_id(google_id) when is_binary(google_id) do
    Repo.get_by(User, google_id: google_id)
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a user from Google OAuth data.

  ## Examples

      iex> create_user_from_google(%{email: "test@example.com", ...})
      {:ok, %User{}}

      iex> create_user_from_google(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_from_google(attrs \\ %{}) do
    %User{}
    |> User.google_registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{username: "john", password: "secret123"})
      {:ok, %User{}}

      iex> register_user(%{username: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Authenticates a user by username and password.

  Performs secure authentication with timing attack prevention.
  Uses constant-time operations to prevent username enumeration.

  ## Parameters

  - `username` - Username to authenticate
  - `password` - Plain text password

  ## Returns

  - `{:ok, user}` - Authentication successful
  - `{:error, :invalid_password}` - User found but password incorrect
  - `{:error, :invalid_username}` - Username not found

  ## Security Features

  - Constant-time password verification with Bcrypt
  - Timing attack prevention via `Bcrypt.no_user_verify/0`
  - Clear error types for logging and debugging

  ## Examples

      iex> authenticate_user("john", "correct_password")
      {:ok, %User{}}

      iex> authenticate_user("john", "wrong_password")
      {:error, :invalid_password}

      iex> authenticate_user("nonexistent", "password")
      {:error, :invalid_username}
  """
  @spec authenticate_user(String.t(), String.t()) :: 
    {:ok, User.t()} | {:error, :invalid_password | :invalid_username}
  def authenticate_user(username, password) when is_binary(username) and is_binary(password) do
    user = get_user_by_username(username)

    cond do
      user && User.valid_password?(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        Bcrypt.no_user_verify()
        {:error, :invalid_username}
    end
  end

  @doc """
  Generates a JWT token for a user.

  ## Examples

      iex> generate_user_session_token(user)
      {:ok, "jwt_token"}

  """
  def generate_user_session_token(user) do
    RouteWiseApi.Guardian.encode_and_sign(user)
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    case RouteWiseApi.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        RouteWiseApi.Guardian.resource_from_claims(claims)

      {:error, _reason} ->
        nil
    end
  end

  @doc """
  Finds or creates a user from Google OAuth info.
  """

  def find_or_create_user_from_google(google_user_info) do
    case get_user_by_google_id(google_user_info["sub"]) do
      nil ->
        # Try to find by email first
        case get_user_by_email(google_user_info["email"]) do
          nil ->
            # Create new user
            create_user_from_google(%{
              username: generate_username_from_email(google_user_info["email"]),
              email: google_user_info["email"],
              google_id: google_user_info["sub"],
              full_name: google_user_info["given_name"] <> " " <> google_user_info["family_name"],
              avatar: google_user_info["picture"],
              provider: "google"
            })

          existing_user ->
            # Link Google account to existing user
            update_user(existing_user, %{
              google_id: google_user_info["sub"],
              avatar: google_user_info["picture"],
              provider: "google"
            })
        end

      existing_user ->
        # User already exists, update info
        update_user(existing_user, %{
          full_name: google_user_info["given_name"] <> " " <> google_user_info["family_name"],
          avatar: google_user_info["picture"]
        })
    end
  end

  defp generate_username_from_email(email) do
    base_username = 
      email
      |> String.split("@")
      |> List.first()
      |> String.replace(~r/[^a-zA-Z0-9_]/, "_")

    # Check if username exists, if so append a random number
    case get_user_by_username(base_username) do
      nil -> base_username
      _user -> base_username <> "_" <> Integer.to_string(:rand.uniform(9999))
    end
  end
end
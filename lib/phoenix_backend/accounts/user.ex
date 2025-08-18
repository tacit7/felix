defmodule RouteWiseApi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "users" do
    field :username, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :email, :string
    field :google_id, :string
    field :full_name, :string
    field :avatar, :string
    field :provider, :string, default: "local"

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :password, :email, :full_name])
    |> validate_username(opts)
    |> validate_password(opts)
    |> validate_email()
  end

  @doc """
  A user changeset for Google OAuth registration.
  """
  def google_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :google_id, :full_name, :avatar, :provider])
    |> validate_required([:username, :email, :google_id, :provider])
    |> validate_username()
    |> validate_email()
    |> unique_constraint(:google_id)
  end

  @doc """
  A user changeset for profile updates.
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :full_name, :avatar])
    |> validate_email()
  end

  defp validate_username(changeset, opts \\ []) do
    changeset
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/, 
         message: "must contain only letters, numbers, and underscores")
    |> maybe_validate_unique_username(opts)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`
      # but that would mean the password is hashed even if there are other
      # validation errors. We don't want to hash if the changeset is invalid.
      |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_username(changeset, opts) do
    if Keyword.get(opts, :validate_username, true) do
      changeset
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%RouteWiseApi.Accounts.User{password_hash: password_hash}, password)
      when is_binary(password_hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, password_hash)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
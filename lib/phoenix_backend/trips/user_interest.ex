defmodule RouteWiseApi.Trips.UserInterest do
  use Ecto.Schema
  import Ecto.Changeset

  alias RouteWiseApi.Accounts.User
  alias RouteWiseApi.Trips.InterestCategory

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "user_interests" do
    field :is_enabled, :boolean, default: true
    field :priority, :integer, default: 1

    belongs_to :user, User
    belongs_to :category, InterestCategory

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user interest changeset for creation and updates.
  """
  def changeset(user_interest, attrs) do
    user_interest
    |> cast(attrs, [:is_enabled, :priority, :user_id, :category_id])
    |> validate_required([:user_id, :category_id])
    |> validate_number(:priority, greater_than: 0, less_than_or_equal_to: 5)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint([:user_id, :category_id])
  end

  @doc """
  Creates user interests from a list of category names.
  """
  def from_category_names(category_names, user_id, priority \\ 1) when is_list(category_names) do
    Enum.map(category_names, fn category_name ->
      %{
        user_id: user_id,
        category_id: nil, # Will be resolved by the context
        category_name: category_name,
        is_enabled: true,
        priority: priority
      }
    end)
  end

  @doc """
  Updates user interest priority and enabled status.
  """
  def update_changeset(user_interest, attrs) do
    user_interest
    |> cast(attrs, [:is_enabled, :priority])
    |> validate_number(:priority, greater_than: 0, less_than_or_equal_to: 5)
  end
end
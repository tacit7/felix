defmodule RouteWiseApi.GoogleAPIUsage do
  @moduledoc """
  Schema for tracking Google API usage per day and endpoint type.
  
  Stores persistent data for API call counts with daily granularity.
  Used by GoogleAPITracker for database persistence.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias RouteWiseApi.Repo

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "google_api_usage" do
    field :usage_date, :date
    field :endpoint_type, :string
    field :call_count, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating API usage records.
  """
  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [:usage_date, :endpoint_type, :call_count, :metadata])
    |> validate_required([:usage_date, :endpoint_type, :call_count])
    |> validate_number(:call_count, greater_than_or_equal_to: 0)
    |> validate_inclusion(:endpoint_type, ["places", "details", "autocomplete", "photos", "geocoding"])
    |> unique_constraint([:usage_date, :endpoint_type])
  end

  @doc """
  Get or create usage record for a specific date and endpoint.
  """
  def get_or_create_usage(date, endpoint_type) do
    case Repo.get_by(__MODULE__, usage_date: date, endpoint_type: endpoint_type) do
      nil ->
        %__MODULE__{}
        |> changeset(%{
          usage_date: date,
          endpoint_type: endpoint_type,
          call_count: 0
        })
        |> Repo.insert()
        
      usage ->
        {:ok, usage}
    end
  end

  @doc """
  Increment the call count for a specific date and endpoint.
  """
  def increment_usage(date, endpoint_type, increment \\ 1) do
    {:ok, usage} = get_or_create_usage(date, endpoint_type)
    
    usage
    |> changeset(%{call_count: usage.call_count + increment})
    |> Repo.update()
  end

  @doc """
  Get total calls for a specific date.
  """
  def get_daily_total(date) do
    from(u in __MODULE__,
      where: u.usage_date == ^date,
      select: sum(u.call_count)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      total -> total
    end
  end

  @doc """
  Get total calls for a specific month.
  """
  def get_monthly_total(year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)
    
    from(u in __MODULE__,
      where: u.usage_date >= ^start_date and u.usage_date <= ^end_date,
      select: sum(u.call_count)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      total -> total
    end
  end

  @doc """
  Get breakdown by endpoint type for a specific date.
  """
  def get_daily_breakdown(date) do
    from(u in __MODULE__,
      where: u.usage_date == ^date,
      select: {u.endpoint_type, u.call_count}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Get breakdown by endpoint type for a specific month.
  """
  def get_monthly_breakdown(year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)
    
    from(u in __MODULE__,
      where: u.usage_date >= ^start_date and u.usage_date <= ^end_date,
      group_by: u.endpoint_type,
      select: {u.endpoint_type, sum(u.call_count)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Sync ETS counters to database for persistence.
  """
  def sync_from_ets(ets_data) when is_map(ets_data) do
    Enum.each(ets_data, fn {key, count} ->
      case parse_ets_key(key) do
        {:ok, date, endpoint_type} when count > 0 ->
          increment_usage(date, endpoint_type, count)
          
        _ ->
          :ignore
      end
    end)
  end

  @doc """
  Load usage data from database into ETS format.
  """
  def load_to_ets(days_back \\ 2) do
    start_date = Date.add(Date.utc_today(), -days_back)
    
    from(u in __MODULE__,
      where: u.usage_date >= ^start_date,
      select: {u.usage_date, u.endpoint_type, u.call_count}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {date, endpoint_type, count}, acc ->
      # Generate ETS-compatible keys
      day_key = format_day_key(date)
      month_key = format_month_key(date)
      
      acc
      |> Map.put(day_key, Map.get(acc, day_key, 0) + count)
      |> Map.put("#{day_key}_#{endpoint_type}", count)
      |> Map.put(month_key, Map.get(acc, month_key, 0) + count)
      |> Map.put("#{month_key}_#{endpoint_type}", Map.get(acc, "#{month_key}_#{endpoint_type}", 0) + count)
    end)
  end

  # Private helper functions

  defp parse_ets_key("day_" <> rest) do
    case String.split(rest, "_") do
      [year, month, day] ->
        with {year_int, ""} <- Integer.parse(year),
             {month_int, ""} <- Integer.parse(month),
             {day_int, ""} <- Integer.parse(day),
             {:ok, date} <- Date.new(year_int, month_int, day_int) do
          {:ok, date, "total"}
        else
          _ -> :error
        end
        
      [year, month, day, endpoint_type] ->
        with {year_int, ""} <- Integer.parse(year),
             {month_int, ""} <- Integer.parse(month),
             {day_int, ""} <- Integer.parse(day),
             {:ok, date} <- Date.new(year_int, month_int, day_int) do
          {:ok, date, endpoint_type}
        else
          _ -> :error
        end
        
      _ -> :error
    end
  end
  
  defp parse_ets_key(_), do: :error

  defp format_day_key(%Date{year: year, month: month, day: day}) do
    "day_#{year}_#{String.pad_leading(to_string(month), 2, "0")}_#{String.pad_leading(to_string(day), 2, "0")}"
  end

  defp format_month_key(%Date{year: year, month: month}) do
    "month_#{year}_#{String.pad_leading(to_string(month), 2, "0")}"
  end
end
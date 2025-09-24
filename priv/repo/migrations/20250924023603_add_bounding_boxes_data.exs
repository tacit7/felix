defmodule RouteWiseApi.Repo.Migrations.AddBoundingBoxesData do
  use Ecto.Migration

  def up do
    # Note: Bounding box data will be populated separately using:
    # mix populate_bounding_boxes
    IO.puts("""
    📍 Migration complete!

    To populate bounding box data for locations, run:
      mix populate_bounding_boxes
    """)
  end

  def down do
    # This migration doesn't modify the schema, only adds data
    # Bounding box data can remain as is during rollback
  end
end

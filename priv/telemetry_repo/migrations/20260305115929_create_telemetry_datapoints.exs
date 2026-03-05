defmodule MusicLibrary.TelemetryRepo.Migrations.CreateTelemetryDatapoints do
  use Ecto.Migration

  def change do
    create table(:telemetry_datapoints) do
      add :metric_key, :text, null: false
      add :label, :text
      add :measurement, :real, null: false
      add :time, :integer, null: false
    end

    # Serves read queries (ORDER BY time) and prune subselect (ORDER BY id DESC)
    create index(:telemetry_datapoints, [:metric_key, :time])
  end
end

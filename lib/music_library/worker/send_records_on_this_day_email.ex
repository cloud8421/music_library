defmodule MusicLibrary.Worker.SendRecordsOnThisDayEmail do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias MusicLibrary.RecordsOnThisDayEmail

  @impl Oban.Worker
  def perform(_) do
    today = DateTime.now!(MusicLibrary.default_timezone()) |> DateTime.to_date()
    RecordsOnThisDayEmail.send(today)
  end
end

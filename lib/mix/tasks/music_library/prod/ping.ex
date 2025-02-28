defmodule Mix.Tasks.MusicLibrary.Prod.Ping do
  use Mix.Task
  @shortdoc "Ping the production instance"
  @moduledoc """
  Ping the production instance - useful to wake it up if suspended.
  """

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:req)
    Mix.Shell.IO.info("==> Pinging the production instance")

    Req.get!("https://music-library.claudio-ortolina.org/api")
  end
end

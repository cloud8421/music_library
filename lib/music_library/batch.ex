defmodule MusicLibrary.Batch do
  alias MusicLibrary.Repo

  require Logger

  @spec run_on_all(Ecto.Queryable.t(), String.t(), (struct() ->
                                                      :ok | {:ok, term()} | {:error, term()})) ::
          {:ok, [String.t()]}
  def run_on_all(queryable, label, fun) do
    stream = Repo.stream(queryable, max_rows: 50)

    Repo.transaction(
      fn ->
        Enum.reduce(stream, [], fn record, acc ->
          case fun.(record) do
            {:error, reason} ->
              Logger.error(
                "Failed to run function on #{label} #{record.id} with #{inspect(reason)}"
              )

              [record.id | acc]

            :ok ->
              acc

            {:ok, _result} ->
              acc
          end
        end)
      end,
      timeout: :infinity
    )
  end
end

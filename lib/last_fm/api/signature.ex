defmodule LastFm.API.Signature do
  def generate(params, shared_secret) do
    encoded_params =
      params
      # Params needs to be ASCII ordered alphabetically
      |> Enum.sort()
      |> Enum.map_join(fn {key, value} ->
        "#{key}#{value}"
      end)

    :crypto.hash(:md5, encoded_params <> shared_secret) |> Base.encode16(case: :lower)
  end
end

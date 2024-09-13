defmodule MusicLibrary.Records.Parser do
  alias MusicLibrary.Records.Record

  def from_entry_contents(entry_contents) do
    with {:ok, meta, _body} <- FrontMatter.parse(entry_contents) do
      {:ok,
       %Record{
         type: parse_subtype(meta["subType"]),
         musicbrainz_id: meta["id"],
         title: meta["title"],
         year: meta["year"],
         image: meta["image"],
         genres: meta["genres"]
       }}
    end
  end

  defp parse_subtype("Album"), do: :album
  defp parse_subtype("ep"), do: :ep
  defp parse_subtype("Live"), do: :live
  defp parse_subtype("Compilation"), do: :compilation
  defp parse_subtype("Single"), do: :single
  defp parse_subtype(_), do: :other
end

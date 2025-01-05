defmodule Obsidian.Parser do
  alias Obsidian.Entry

  def from_file_contents(file_contents) do
    with {:ok, meta} <- parse_frontmatter(file_contents) do
      {:ok,
       %Entry{
         type: parse_subtype(meta["subType"]),
         musicbrainz_id: meta["id"],
         title: meta["title"],
         release: meta["year"] |> parse_release(),
         cover_url: meta["image"],
         genres: meta["genres"]
       }}
    end
  end

  defp parse_frontmatter("---\n" <> rest) do
    with [frontmatter, _] <- String.split(rest, "\n---\n"),
         {:ok, [meta]} <- YamlElixir.read_all_from_string(frontmatter) do
      {:ok, meta}
    else
      _ ->
        {:error, "Invalid frontmatter"}
    end
  end

  defp parse_frontmatter(_file_contents) do
    {:error, "Invalid frontmatter"}
  end

  defp parse_subtype("Album"), do: :album
  defp parse_subtype("ep"), do: :ep
  defp parse_subtype("Live"), do: :live
  defp parse_subtype("Compilation"), do: :compilation
  defp parse_subtype("Single"), do: :single
  defp parse_subtype(_), do: :other

  defp parse_release(nil), do: nil
  defp parse_release(year) when is_integer(year), do: Integer.to_string(year)
  defp parse_release(year) when is_binary(year), do: year
end

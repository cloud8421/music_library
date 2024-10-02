defmodule Obsidian.Parser do
  alias Obsidian.Entry

  def from_file_contents(file_contents) do
    with {:ok, [meta]} <- parse_frontmatter(file_contents) do
      {:ok,
       %Entry{
         type: parse_subtype(meta["subType"]),
         musicbrainz_id: meta["id"],
         title: meta["title"],
         release: meta["year"] |> parse_release(),
         image_url: meta["image"],
         genres: meta["genres"]
       }}
    end
  end

  defp parse_frontmatter(file_contents) do
    case file_contents do
      "---\n" <> rest ->
        case String.split(rest, "\n---\n") do
          [frontmatter, _] ->
            case YamlElixir.read_all_from_string(frontmatter) do
              {:ok, meta} -> {:ok, meta}
              {:error, _} -> {:error, "Invalid frontmatter"}
            end

          _ ->
            {:error, "Invalid frontmatter"}
        end

      _ ->
        {:error, "Invalid frontmatter"}
    end
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

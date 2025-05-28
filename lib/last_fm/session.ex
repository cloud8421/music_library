defmodule LastFm.Session do
  require Record

  defstruct [:name, :key, :pro]

  Record.defrecord(
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecord(:xmlText, Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl"))

  @doc """
  Parses a Last.fm session XML response into a Session struct.

  ## Examples

      iex> xml = \"\"\"
      ...> <?xml version="1.0" encoding="UTF-8"?>
      ...> <lfm status="ok">
      ...>   <session>
      ...>     <name>cloud8421</name>
      ...>     <key>super-secret</key>
      ...>     <subscriber>1</subscriber>
      ...>   </session>
      ...> </lfm>
      ...> \"\"\"
      iex> LastFm.Session.parse(xml)
      %LastFm.Session{
        name: "cloud8421",
        key: "super-secret",
        pro: true
      }
  """
  def parse(xml_string) do
    doc = scan(xml_string)

    name =
      doc
      |> first("//lfm/session/name")
      |> text()

    key =
      doc
      |> first("//lfm/session/key")
      |> text()

    subscriber =
      doc
      |> first("//lfm/session/subscriber")
      |> text()

    %__MODULE__{
      name: name,
      key: key,
      pro: subscriber == "1"
    }
  end

  defp scan(xml_string) do
    {doc, []} =
      xml_string
      |> :binary.bin_to_list()
      |> :xmerl_scan.string(quiet: true)

    doc
  end

  defp first(node, path), do: node |> xpath(path) |> take_one()

  defp take_one([head | _]), do: head
  defp take_one(_), do: nil

  defp xpath(nil, _), do: []

  defp xpath(node, path) do
    :xmerl_xpath.string(to_charlist(path), node)
  end

  def text(node), do: node |> xpath(~c"./text()") |> extract_text()

  defp extract_text([xmlText(value: value)]), do: List.to_string(value)
  defp extract_text(_x), do: nil
end

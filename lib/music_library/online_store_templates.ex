defmodule MusicLibrary.OnlineStoreTemplates do
  @moduledoc """
  Includes functions to manipulate online store templates.
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate
  alias MusicLibrary.Repo

  def list_enabled_templates do
    OnlineStoreTemplate
    |> where([t], t.enabled == true)
    |> order_by([t], fragment("? COLLATE NOCASE ASC", t.name))
    |> Repo.all()
  end

  def list_templates do
    OnlineStoreTemplate
    |> order_by([t], fragment("? COLLATE NOCASE ASC", t.name))
    |> Repo.all()
  end

  def get_template!(id), do: Repo.get!(OnlineStoreTemplate, id)

  def create_template(attrs \\ %{}) do
    %OnlineStoreTemplate{}
    |> OnlineStoreTemplate.changeset(attrs)
    |> Repo.insert()
  end

  def update_template(%OnlineStoreTemplate{} = template, attrs) do
    template
    |> OnlineStoreTemplate.changeset(attrs)
    |> Repo.update()
  end

  def delete_template(%OnlineStoreTemplate{} = template) do
    Repo.delete(template)
  end

  def change_template(%OnlineStoreTemplate{} = template, attrs \\ %{}) do
    OnlineStoreTemplate.changeset(template, attrs)
  end

  def generate_url(template, record) do
    artists_string = Enum.map_join(record.artists, " ", & &1.name)
    format_string = Atom.to_string(record.format)

    template.url_template
    |> String.replace("{artist}", URI.encode_www_form(artists_string))
    |> String.replace("{title}", URI.encode_www_form(record.title))
    |> String.replace("{format}", URI.encode_www_form(format_string))
  end
end

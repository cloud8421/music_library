defmodule MusicLibrary.OnlineStoreTemplates do
  @moduledoc """
  The OnlineStoreTemplates context.
  """

  import Ecto.Query, warn: false
  alias MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate
  alias MusicLibrary.Repo

  @doc """
  Returns the list of enabled online store templates ordered by name.
  """
  def list_enabled_templates do
    OnlineStoreTemplate
    |> where([t], t.enabled == true)
    |> order_by([t], fragment("? COLLATE NOCASE ASC", t.name))
    |> Repo.all()
  end

  @doc """
  Returns the list of all online store templates for management.
  """
  def list_templates do
    OnlineStoreTemplate
    |> order_by([t], fragment("? COLLATE NOCASE ASC", t.name))
    |> Repo.all()
  end

  @doc """
  Gets a single online store template.
  """
  def get_template!(id), do: Repo.get!(OnlineStoreTemplate, id)

  @doc """
  Creates an online store template.
  """
  def create_template(attrs \\ %{}) do
    %OnlineStoreTemplate{}
    |> OnlineStoreTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an online store template.
  """
  def update_template(%OnlineStoreTemplate{} = template, attrs) do
    template
    |> OnlineStoreTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an online store template.
  """
  def delete_template(%OnlineStoreTemplate{} = template) do
    Repo.delete(template)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking online store template changes.
  """
  def change_template(%OnlineStoreTemplate{} = template, attrs \\ %{}) do
    OnlineStoreTemplate.changeset(template, attrs)
  end

  @doc """
  Generates a URL from a template by replacing variables with record data.
  """
  def generate_url(template, record) do
    artists_string = Enum.map_join(record.artists, " ", & &1.name)
    format_string = Atom.to_string(record.format)

    template.url_template
    |> String.replace("{artist}", URI.encode_www_form(artists_string))
    |> String.replace("{title}", URI.encode_www_form(record.title))
    |> String.replace("{format}", URI.encode_www_form(format_string))
  end

  def favicon_url(template) do
    uri = URI.parse(template.url_template)
    "https://www.google.com/s2/favicons?domain=#{uri.host}&sz=16"
  end
end

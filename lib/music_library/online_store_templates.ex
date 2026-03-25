defmodule MusicLibrary.OnlineStoreTemplates do
  @moduledoc """
  Includes functions to manipulate online store templates.
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.OnlineStoreTemplates.OnlineStoreTemplate
  alias MusicLibrary.Repo

  @pagination Application.compile_env!(:music_library, :pagination)

  @spec list_enabled_templates() :: [OnlineStoreTemplate.t()]
  def list_enabled_templates do
    OnlineStoreTemplate
    |> where([t], t.enabled == true)
    |> order_by([t], fragment("? COLLATE NOCASE ASC", t.name))
    |> Repo.all()
  end

  @spec list_templates() :: [OnlineStoreTemplate.t()]
  def list_templates do
    OnlineStoreTemplate
    |> order_by([t], fragment("? COLLATE NOCASE ASC", t.name))
    |> Repo.all()
  end

  @type list_opts :: [query: String.t(), offset: non_neg_integer(), limit: non_neg_integer()]

  @spec list_templates(list_opts()) :: [OnlineStoreTemplate.t()]
  def list_templates(opts) do
    query =
      OnlineStoreTemplate
      |> order_by([t], fragment("? COLLATE NOCASE ASC", t.name))
      |> filter_templates(opts)

    offset = Keyword.get(opts, :offset, 0)
    limit = Keyword.get(opts, :limit, @pagination[:default_page_size])

    query
    |> offset(^offset)
    |> limit(^limit)
    |> Repo.all()
  end

  @spec count_templates(list_opts()) :: non_neg_integer()
  def count_templates(opts \\ []) do
    OnlineStoreTemplate
    |> filter_templates(opts)
    |> Repo.aggregate(:count)
  end

  @spec get_template!(String.t()) :: OnlineStoreTemplate.t()
  def get_template!(id), do: Repo.get!(OnlineStoreTemplate, id)

  @spec create_template(map()) :: {:ok, OnlineStoreTemplate.t()} | {:error, Ecto.Changeset.t()}
  def create_template(attrs \\ %{}) do
    %OnlineStoreTemplate{}
    |> OnlineStoreTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_template(OnlineStoreTemplate.t(), map()) ::
          {:ok, OnlineStoreTemplate.t()} | {:error, Ecto.Changeset.t()}
  def update_template(%OnlineStoreTemplate{} = template, attrs) do
    template
    |> OnlineStoreTemplate.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_template(OnlineStoreTemplate.t()) ::
          {:ok, OnlineStoreTemplate.t()} | {:error, Ecto.Changeset.t()}
  def delete_template(%OnlineStoreTemplate{} = template) do
    Repo.delete(template)
  end

  @spec change_template(OnlineStoreTemplate.t(), map()) :: Ecto.Changeset.t()
  def change_template(%OnlineStoreTemplate{} = template, attrs \\ %{}) do
    OnlineStoreTemplate.changeset(template, attrs)
  end

  @spec generate_url(OnlineStoreTemplate.t(), map()) :: String.t()
  def generate_url(template, record) do
    artists_string = Enum.map_join(record.artists, " ", & &1.name)
    format_string = Atom.to_string(record.format)

    template.url_template
    |> String.replace("{artist}", URI.encode_www_form(artists_string))
    |> String.replace("{title}", URI.encode_www_form(record.title))
    |> String.replace("{format}", URI.encode_www_form(format_string))
  end

  defp filter_templates(query, opts) do
    case Keyword.get(opts, :query) do
      q when q in [nil, ""] ->
        query

      q ->
        like = "%#{q}%"

        from t in query,
          where: like(t.name, ^like) or like(t.description, ^like)
    end
  end
end

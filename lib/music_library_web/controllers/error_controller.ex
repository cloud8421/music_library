defmodule MusicLibraryWeb.ErrorController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Errors

  def index(conn, params) do
    status = parse_status(params["status"])
    muted = parse_muted(params["muted"])
    search = params["search"]
    limit = max(1, parse_int(params["limit"], 50))
    offset = max(0, parse_int(params["offset"], 0))

    opts =
      []
      |> maybe_put(:status, status)
      |> maybe_put(:muted, muted)
      |> Keyword.put(:search, search)
      |> Keyword.put(:limit, limit)
      |> Keyword.put(:offset, offset)

    %{errors: errors, total: total} = Errors.list_errors(opts)

    render(conn, :index, errors: errors, total: total, limit: limit, offset: offset)
  end

  def show(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {id_int, ""} when id_int > 0 ->
        case Errors.get_error(id_int) do
          {:ok, error} ->
            render(conn, :show, error: error)

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Not Found"})
        end

      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Not Found"})
    end
  end

  def mute(conn, %{"id" => id}), do: perform_action(conn, id, &Errors.mute_error/1)
  def unmute(conn, %{"id" => id}), do: perform_action(conn, id, &Errors.unmute_error/1)
  def resolve(conn, %{"id" => id}), do: perform_action(conn, id, &Errors.resolve_error/1)
  def unresolve(conn, %{"id" => id}), do: perform_action(conn, id, &Errors.unresolve_error/1)

  # -- private helpers --

  defp perform_action(conn, id, action_fn) do
    case Integer.parse(id) do
      {id_int, ""} when id_int > 0 ->
        case action_fn.(id_int) do
          {:ok, error} ->
            render(conn, :update, error: error)

          {:error, :not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "Not Found"})

          {:error, _changeset} ->
            conn |> put_status(:unprocessable_entity) |> json(%{error: "Update failed"})
        end

      _ ->
        conn |> put_status(:not_found) |> json(%{error: "Not Found"})
    end
  end

  defp parse_status(nil), do: nil
  defp parse_status("resolved"), do: :resolved
  defp parse_status("unresolved"), do: :unresolved
  defp parse_status(_), do: nil

  defp parse_muted(nil), do: nil
  defp parse_muted("true"), do: true
  defp parse_muted("false"), do: false
  defp parse_muted(_), do: nil

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp parse_int(_, default), do: default

  defp maybe_put(kw, _key, nil), do: kw
  defp maybe_put(kw, key, value), do: Keyword.put(kw, key, value)
end

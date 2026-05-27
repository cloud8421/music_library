defmodule MusicLibrary.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use Oban.Testing, repo: MusicLibrary.BackgroundRepo, engine: Oban.Engines.Lite

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import MusicLibrary.DataCase

      alias MusicLibrary.Repo
    end
  end

  setup tags do
    MusicLibrary.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    repo_pid = Sandbox.start_owner!(MusicLibrary.Repo, shared: not tags[:async])

    background_repo_pid =
      Sandbox.start_owner!(MusicLibrary.BackgroundRepo, shared: not tags[:async])

    on_exit(fn ->
      Sandbox.stop_owner(repo_pid)
      Sandbox.stop_owner(background_repo_pid)
    end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

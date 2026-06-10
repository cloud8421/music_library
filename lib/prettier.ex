defmodule Prettier do
  @moduledoc false

  @behaviour Phoenix.LiveView.HTMLFormatter.TagFormatter

  require Logger

  @impl true
  # sobelow_skip ["Traversal.FileModule"]
  def render_tag({"script", attrs, content}, _opts) do
    suffix =
      case attrs do
        %{":type" => _} ->
          # assume ColocatedHook / ColocatedJS and check for extension in manifest attribute
          Map.get(attrs, "manifest", "index.js")

        _ ->
          "tmp.js"
      end

    tmp_file =
      Path.join(System.tmp_dir!(), "prettier_#{System.unique_integer([:positive])}_#{suffix}")

    try do
      File.write!(tmp_file, content)

      # This example assumes that your project has prettier installed as a dependency
      # in your package.json. If not, you should pin prettier to a specific version like
      # "prettier@3.8.1" to avoid potential issues when prettier updates.
      case System.cmd("prettier", [tmp_file], stderr_to_stdout: true) do
        {output, 0} ->
          {:ok, String.trim(output)}

        {error, _} ->
          Logger.error("Failed to format with prettier: #{error}")
          :skip
      end
    after
      File.rm(tmp_file)
    end
  end
end

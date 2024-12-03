defmodule LastFm.Config do
  @type t :: %{
          api: module(),
          api_key: String.t(),
          user: String.t(),
          refresh_interval: pos_integer()
        }

  defstruct api: LastFm.Api,
            api_key: "",
            user: "",
            refresh_interval: 60_000

  @spec new(Enumerable.t()) :: t()
  def new(opts) do
    struct(__MODULE__, opts)
  end
end

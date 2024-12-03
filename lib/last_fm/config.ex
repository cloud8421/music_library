defmodule LastFm.Config do
  @type t :: %{
          api: module(),
          api_key: String.t(),
          user: String.t(),
          auto_refresh: boolean(),
          refresh_interval: pos_integer()
        }

  defstruct api: LastFm.Api,
            api_key: "",
            user: "",
            auto_refresh: true,
            refresh_interval: 60_000

  @spec resolve(atom) :: t
  def resolve(otp_app) do
    app_config =
      otp_app
      |> Application.get_env(LastFm)

    struct(__MODULE__, app_config)
  end
end

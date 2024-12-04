defmodule LastFm.Config do
  @type t :: %{
          api: module(),
          api_key: String.t(),
          user: String.t(),
          auto_refresh: boolean(),
          refresh_interval: pos_integer(),
          user_agent: String.t()
        }

  defstruct api: LastFm.Api,
            api_key: "",
            user: "",
            auto_refresh: true,
            refresh_interval: 60_000,
            user_agent: "change me"

  @schema NimbleOptions.new!(
            api: [
              type: :atom,
              required: true
            ],
            api_key: [
              type: :string,
              required: true
            ],
            user: [
              type: :string,
              required: true
            ],
            auto_refresh: [
              type: :boolean,
              required: false,
              default: true
            ],
            refresh_interval: [
              type: :pos_integer,
              required: false,
              default: 60_000
            ],
            user_agent: [
              type: :string,
              required: false,
              default: "change me"
            ]
          )

  @doc NimbleOptions.docs(@schema)
  @spec resolve(atom) :: t
  def resolve(otp_app) do
    app_config =
      Application.get_env(otp_app, LastFm)
      |> NimbleOptions.validate!(@schema)

    struct(__MODULE__, app_config)
  end
end

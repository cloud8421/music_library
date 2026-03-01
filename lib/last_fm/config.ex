defmodule LastFm.Config do
  @type t :: %__MODULE__{
          api_key: String.t(),
          shared_secret: String.t(),
          user: String.t(),
          auto_refresh: boolean(),
          refresh_interval: pos_integer(),
          user_agent: String.t(),
          req_options: Keyword.t(),
          api_cooldown: non_neg_integer()
        }

  @enforce_keys [:api_key, :user]
  defstruct api_key: "",
            shared_secret: "",
            user: "",
            auto_refresh: true,
            refresh_interval: 60_000,
            user_agent: "change me",
            req_options: [],
            api_cooldown: 500

  @schema NimbleOptions.new!(
            api_key: [
              type: :string,
              required: true
            ],
            shared_secret: [
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
            ],
            req_options: [
              type: :keyword_list,
              required: false,
              default: []
            ],
            api_cooldown: [
              type: :integer,
              required: false,
              default: 500
            ]
          )

  @doc NimbleOptions.docs(@schema)
  @spec resolve(Application.app()) :: t | no_return
  def resolve(otp_app) do
    app_config =
      Application.get_env(otp_app, LastFm)
      |> NimbleOptions.validate!(@schema)

    struct(__MODULE__, app_config)
  end
end

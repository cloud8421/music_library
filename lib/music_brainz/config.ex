defmodule MusicBrainz.Config do
  @type t :: %__MODULE__{
          user_agent: String.t(),
          req_options: Keyword.t(),
          api_cooldown: non_neg_integer()
        }

  @enforce_keys [:user_agent]
  defstruct user_agent: "change me",
            req_options: [],
            api_cooldown: 500

  @schema NimbleOptions.new!(
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
      Application.get_env(otp_app, MusicBrainz)
      |> NimbleOptions.validate!(@schema)

    struct(__MODULE__, app_config)
  end
end

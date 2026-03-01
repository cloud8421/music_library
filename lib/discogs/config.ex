defmodule Discogs.Config do
  @type t :: %__MODULE__{
          personal_access_token: String.t(),
          user_agent: String.t(),
          req_options: Keyword.t(),
          api_cooldown: non_neg_integer()
        }

  @enforce_keys [:personal_access_token]
  defstruct personal_access_token: "",
            user_agent: "change me",
            req_options: [],
            api_cooldown: 1000

  @schema NimbleOptions.new!(
            personal_access_token: [
              type: :string,
              required: true
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
              default: 1000
            ]
          )

  @doc NimbleOptions.docs(@schema)
  @spec resolve(Application.app()) :: t | no_return
  def resolve(otp_app) do
    app_config =
      Application.get_env(otp_app, Discogs)
      |> NimbleOptions.validate!(@schema)

    struct(__MODULE__, app_config)
  end
end

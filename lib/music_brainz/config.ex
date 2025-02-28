defmodule MusicBrainz.Config do
  @type t :: %__MODULE__{
          user_agent: String.t(),
          req_options: Keyword.t()
        }

  @enforce_keys [:user_agent]
  defstruct user_agent: "change me",
            req_options: []

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
            ]
          )

  @doc NimbleOptions.docs(@schema)
  @spec resolve(atom) :: t | no_return
  def resolve(otp_app) do
    app_config =
      Application.get_env(otp_app, MusicBrainz)
      |> NimbleOptions.validate!(@schema)

    struct(__MODULE__, app_config)
  end
end

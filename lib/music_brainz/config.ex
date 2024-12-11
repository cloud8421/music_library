defmodule MusicBrainz.Config do
  @type t :: %{
          api: module(),
          user_agent: String.t()
        }

  defstruct api: MusicBrainz.APIImpl,
            user_agent: "change me"

  @schema NimbleOptions.new!(
            api: [
              type: :atom,
              required: true
            ],
            user_agent: [
              type: :string,
              required: false,
              default: "change me"
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

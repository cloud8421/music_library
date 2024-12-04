defmodule MusicBrainz.Config do
  @type t :: %{
          api: module(),
          user_agent: String.t()
        }

  defstruct api: MusicBrainz.APIImpl,
            user_agent: "change me"

  @spec resolve(atom) :: t
  def resolve(otp_app) do
    app_config = Application.get_env(otp_app, MusicBrainz)

    struct(__MODULE__, app_config)
  end
end

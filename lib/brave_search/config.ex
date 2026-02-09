defmodule BraveSearch.Config do
  @type t :: %__MODULE__{
          api_key: String.t(),
          user_agent: String.t(),
          req_options: Keyword.t()
        }

  @enforce_keys [:api_key]
  defstruct api_key: "",
            user_agent: "change me",
            req_options: []

  @schema NimbleOptions.new!(
            api_key: [
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
            ]
          )

  @doc NimbleOptions.docs(@schema)
  @spec resolve(Application.app()) :: t | no_return
  def resolve(otp_app) do
    app_config =
      Application.get_env(otp_app, BraveSearch)
      |> NimbleOptions.validate!(@schema)

    struct(__MODULE__, app_config)
  end
end

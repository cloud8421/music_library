defmodule OpenAI.Completion do
  @enforce_keys [:content]
  defstruct content: "",
            temperature: 0.2,
            role: "user",
            model: "gpt-4o-mini"

  @type t :: %__MODULE__{
          content: String.t(),
          temperature: float(),
          role: String.t(),
          model: String.t()
        }
end

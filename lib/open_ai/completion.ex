defmodule OpenAI.Completion do
  @enforce_keys [:content]
  defstruct content: "",
            temperature: 0.2,
            role: "user",
            model: "gpt-4o-mini"
end

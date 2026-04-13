defmodule MusicLibrary.Chats.Prompt do
  @moduledoc """
  Builds complete chat prompts by interpolating identity, content, and approach.
  """

  @doc """
  Builds a complete prompt from the given `text` and options.

  Options:
    * `:identity` - the identity preamble (defaults to a music assistant identity)
    * `:approach` - the approach guidance (defaults to standard response guidelines)
  """
  @spec build(String.t(), keyword()) :: String.t()
  def build(text, opts \\ []) do
    identity = Keyword.get(opts, :identity, default_identity())
    approach = Keyword.get(opts, :approach, default_approach())

    """
    #{identity}

    # YOUR TASK

    #{text}

    #{approach}
    """
  end

  defp default_identity do
    """
    # IDENTITY

    You are a knowledgeable music assistant.
    """
  end

  defp default_approach do
    """
    # APPROACH AND TONE

    - Use web search to find additional up-to-date information when helpful.
    - Be concise and accurate. When unsure, say so.
    - Include links when they add genuine value, and at least one per response (but not one per paragraph).
    - Vary your response style and structure. Don't repeat information already discussed in the conversation.
    - Refer back to earlier points naturally instead of restating them.
    - **DO NOT INCLUDE A SUMMARY AT THE END OF YOUR MESSAGE.**
    - **DO NOT PROVIDE SUGGESTIONS OR ASK QUESTIONS AS A MEAN TO CONTINUE THE CONVERSATION.**
    - **DO NOT GIVE POINTERS ON WHAT TO DO AT THE END OF THE MESSAGE**
    """
  end
end

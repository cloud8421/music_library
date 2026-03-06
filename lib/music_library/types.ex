defmodule MusicLibrary.Types do
  @moduledoc false

  @type pagination_opts :: [
          limit: non_neg_integer(),
          offset: non_neg_integer(),
          order: atom()
        ]
end

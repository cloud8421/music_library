defmodule MusicLibrary.BarcodeScan.Result do
  defstruct [:status, :number, :record_id, :release]

  @type t :: %__MODULE__{
          status: :new | :wishlisted | :collected | :not_found,
          number: String.t(),
          record_id: String.t() | nil,
          release: map() | nil
        }

  @spec new(String.t(), map()) :: t()
  def new(number, release) do
    %__MODULE__{
      number: number,
      status: :new,
      release: release
    }
  end

  @spec wishlisted(String.t(), String.t(), map()) :: t()
  def wishlisted(number, record_id, release) do
    %__MODULE__{
      number: number,
      status: :wishlisted,
      record_id: record_id,
      release: release
    }
  end

  @spec collected(String.t(), String.t(), map()) :: t()
  def collected(number, record_id, release) do
    %__MODULE__{
      number: number,
      status: :collected,
      record_id: record_id,
      release: release
    }
  end

  @spec not_found(String.t()) :: t()
  def not_found(number) do
    %__MODULE__{
      number: number,
      status: :not_found
    }
  end
end

defmodule MusicLibrary.BarcodeScan.Result do
  defstruct [:status, :number, :record_id, :release]

  def new(number, release) do
    %__MODULE__{
      number: number,
      status: :new,
      release: release
    }
  end

  def wishlisted(number, record_id, release) do
    %__MODULE__{
      number: number,
      status: :wishlisted,
      record_id: record_id,
      release: release
    }
  end

  def collected(number, record_id, release) do
    %__MODULE__{
      number: number,
      status: :collected,
      record_id: record_id,
      release: release
    }
  end

  def not_found(number) do
    %__MODULE__{
      number: number,
      status: :not_found
    }
  end
end

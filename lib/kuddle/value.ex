defmodule Kuddle.Value do
  @moduledoc """
  Used to represent a value for attributes.
  """
  defstruct [
    value: nil,
    annotations: [],
    type: :id,
    format: :plain,
  ]

  @type format :: :plain
                | :bin
                | :oct
                | :dec
                | :hex

  @type value_type :: :id
                    | :integer
                    | :float
                    | :boolean
                    | :string
                    | :null

  @type t :: %__MODULE__{
    value: any(),
    annotations: [String.t()],
    type: value_type(),
    format: format(),
  }
end

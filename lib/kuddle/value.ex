defmodule Kuddle.Value do
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

  @type t :: %__MODULE__{
    value: any(),
    annotations: [String.t()],
    type: value_type(),
    format: format(),
  }
end

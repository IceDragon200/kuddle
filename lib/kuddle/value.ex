defmodule Kuddle.Value do
  defstruct [
    value: nil,
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
    type: value_type(),
    format: format(),
  }
end

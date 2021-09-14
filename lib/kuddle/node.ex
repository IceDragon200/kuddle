defmodule Kuddle.Node do
  alias Kuddle.Value

  defstruct [
    name: nil,
    annotations: [],
    attributes: [],
    children: nil,
  ]

  @type t :: %__MODULE__{
    name: String.t(),
    annotations: [String.t()],
    attributes: [{key::Value.t(), value::Value.t()} | Value.t()],
    children: [t()] | nil
  }
end

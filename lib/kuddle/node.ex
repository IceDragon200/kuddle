defmodule Kuddle.Node do
  @moduledoc """
  The equivalent of a KDL Node, every node has a name, some optional annotations, attributes
  and children.

  Annotations are plain strings.

  Attributes contain both properties and values in the order that they appeared.

  Children is a list of sub Nodes.
  """
  alias Kuddle.Value

  defstruct [
    name: nil,
    annotations: [],
    attributes: [],
    children: nil,
  ]

  @typedoc """
  An attribute is either a property `{key, value}`, or just a plain value.
  """
  @type attribute :: {key::Value.t(), value::Value.t()} | Value.t()

  @type t :: %__MODULE__{
    name: String.t(),
    annotations: [String.t()],
    attributes: [attribute()],
    children: [t()] | nil
  }
end

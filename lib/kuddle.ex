defmodule Kuddle do
  @moduledoc """
  Kuddle is a KDL (https://github.com/kdl-org/kdl) encoder and decoder.

  It is compliant with both the 1.x and 2.x specifications, simply use the appropriately versioned
  module for your needs.

  And yes UTF-8 still works.

  V2 is the default.
  """
  @type document :: Kuddle.V2.Decoder.document()

  @doc """
  Decode a KDL document into kuddle nodes

  Usage:

      [%Node{name: "node"}] = Kuddle.decode("node")

  """
  @spec decode(String.t()) ::
          {:ok, document(), rest::String.t()}
          | {:error, term()}
  defdelegate decode(blob), to: Kuddle.V2.Decoder

  @doc """
  Encode a kuddle document as serialized KDL

  Usage:

      "node" = Kuddle.encode([%Node{name: "node"}])

  """
  @spec encode(document()) ::
          {:ok, String.t()}
          | {:error, term()}
  defdelegate encode(doc), to: Kuddle.V2.Encoder

  @doc """
  Select allows searching a document for particular nodes by name, and or attributes.

  Usage:

      [%Node{name: "node"}] = Kuddle.select(document, ["node"])

  """
  @spec select(document(), Kuddle.Path.path()) :: document()
  defdelegate select(doc, path), to: Kuddle.Path
end

defmodule Kuddle.V2 do
  @moduledoc """
  This is the V2 interface which handles KDL2 documents, if you need the older encoder and encoder,
  see the V1 module instead.
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
  @spec encode(document(), Keyword.t()) ::
          {:ok, String.t()}
          | {:error, term()}
  defdelegate encode(doc, options \\ []), to: Kuddle.V2.Encoder

  @doc """
  Select allows searching a document for particular nodes by name, and or attributes.

  Usage:

      [%Node{name: "node"}] = Kuddle.select(document, ["node"])

  """
  @spec select(document(), Kuddle.Path.path()) :: document()
  defdelegate select(doc, path), to: Kuddle.Path
end

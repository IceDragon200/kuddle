defmodule Kuddle do
  @moduledoc """
  Kuddle is a KDL (https://github.com/kdl-org/kdl) encoder and decoder.

  Kuddle is KDL 1.0.0 compliant and should be able to process most if not all KDL documents without
  issue.

  And yes UTF-8 works.
  """
  @type document :: Kuddle.Decoder.document()

  @doc """
  Decode a KDL document into kuddle nodes

  Usage:

      [%Node{name: "node"}] = Kuddle.decode("node")

  """
  @spec decode(String.t()) ::
          {:ok, document(), rest::String.t()}
          | {:error, term()}
  defdelegate decode(blob), to: Kuddle.Decoder

  @doc """
  Encode a kuddle document as serialized KDL

  Usage:

      "node" = Kuddle.encode([%Node{name: "node"}])

  """
  @spec encode(document()) ::
          {:ok, String.t()}
          | {:error, term()}
  defdelegate encode(doc), to: Kuddle.Encoder

  @doc """
  Select allows searching a document for particular nodes by name, and or attributes.

  Usage:

      [%Node{name: "node"}] = Kuddle.select(document, ["node"])

  """
  @spec select(document(), Kuddle.Path.path()) :: document()
  defdelegate select(doc, path), to: Kuddle.Path
end

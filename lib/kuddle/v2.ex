defmodule Kuddle.V2 do
  @moduledoc """
  This is the V2 interface which handles KDL2 documents, if you need the older encoder and encoder,
  see the V1 module instead.
  """
  @type document :: Kuddle.V2.Decoder.document()

  @type tokens :: Kuddle.V2.Tokenizer.tokens()

  @doc """
  Decode a KDL document into kuddle nodes

  Usage:

      Kuddle.V2.decode(document)
      {:ok, [%Kuddle.Node{name: "node"}], []} = Kuddle.V2.decode("node")

  ## Examples

      iex> Kuddle.V2.decode("node { node2 1; }")
      {:ok, [%Kuddle.Node{name: "node", children: [%Kuddle.Node{name: "node2", attributes: [%Kuddle.Value{type: :integer, value: 1, format: :dec}]}]}], []}

  """
  @spec decode(String.t()) ::
          {:ok, document(), rest::tokens()}
          | {:error, term()}
  defdelegate decode(blob), to: Kuddle.V2.Decoder

  @doc """
  Decode a KDL blob into kuddle nodes, if the blob is not a valid KDL document this will raise
  a Kuddle.DecodeError.

  ## Usage

      Kuddle.V2.decode!(blob)
      [%Kuddle.Node{name: "node"}] = Kuddle.V2.decode!("node")

  ## Examples

      iex> Kuddle.V2.decode!("node")
      [%Kuddle.Node{name: "node"}]

  """
  @spec decode!(String.t()) :: document()
  defdelegate decode!(blob), to: Kuddle.V2.Decoder

  @doc """
  Encode a kuddle document as serialized KDL

  ## Usage

      {:ok, "node"} = Kuddle.V2.encode([%Kuddle.Node{name: "node"}])

  ## Examples

      iex> Kuddle.V2.encode([%Kuddle.Node{name: "node"}])
      {:ok, "node\\n"}

  """
  @spec encode(document(), Keyword.t()) ::
          {:ok, String.t()}
          | {:error, term()}
  defdelegate encode(doc, options \\ []), to: Kuddle.V2.Encoder

  @doc """
  Encode a kuddle document as serialized KDL, if the document cannot be encoded a Kuddle.EncodeError
  will be raised.

  ## Usage

      "node" = Kuddle.V2.encode!([%Kuddle.Node{name: "node"}])

  ## Examples

      iex> Kuddle.V2.encode!([%Kuddle.Node{name: "node"}])
      "node\\n"

  """
  @spec encode!(document()) :: String.t()
  defdelegate encode!(doc), to: Kuddle.V2.Encoder

  @doc """
  Select allows searching a document for particular nodes by name, and or attributes.

  ## Usage

      Kuddle.V2.select(kdl_document, path)
      [%Kuddle.Node{name: "node"}] = Kuddle.V2.select(document, ["node"])

  ## Examples

      iex> document = Kuddle.V2.decode!("node; node2; node3")
      [%Kuddle.Node{name: "node"}, %Kuddle.Node{name: "node2"}, %Kuddle.Node{name: "node3"}]
      iex> Kuddle.V2.select(document, ["node"])
      [%Kuddle.Node{name: "node"}]

  """
  @spec select(document(), Kuddle.Path.path()) :: document()
  defdelegate select(doc, path), to: Kuddle.Path
end

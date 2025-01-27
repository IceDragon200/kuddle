defmodule Kuddle do
  @moduledoc """
  Kuddle is a KDL (https://github.com/kdl-org/kdl) encoder and decoder.

  It is compliant with both the 1.x and 2.x specifications, simply use the appropriately versioned
  module for your needs.

  And yes UTF-8 still works.

  V2 is the default.
  """
  @type document :: Kuddle.V2.Decoder.document()

  @type tokens :: Kuddle.V2.Tokenizer.tokens()

  @doc """
  Decode a KDL document into kuddle nodes

  ## Usage

      Kuddle.decode(blob)
      {:ok, [%Kuddle.Node{name: "node"}], []} = Kuddle.decode("node")

  ## Examples

      iex> Kuddle.decode("node { node2 1; }")
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

      Kuddle.decode!(blob)
      [%Kuddle.Node{name: "node"}] = Kuddle.decode!("node")

  ## Examples

      iex> Kuddle.decode!("node")
      [%Kuddle.Node{name: "node"}]

  """
  @spec decode!(String.t()) :: document()
  defdelegate decode!(blob), to: Kuddle.V2.Decoder

  @doc """
  Encode a kuddle document as serialized KDL

  ## Usage

      Kuddle.encode(kdl_document)
      "node" = Kuddle.encode([%Kuddle.Node{name: "node"}])

  ## Examples

      iex> Kuddle.encode([%Kuddle.Node{name: "node"}])
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

      "node" = Kuddle.encode!([%Kuddle.Node{name: "node"}])

  ## Examples

      iex> Kuddle.encode!([%Kuddle.Node{name: "node"}])
      "node\\n"

  """
  @spec encode!(document(), Keyword.t()) :: String.t()
  defdelegate encode!(doc, options \\ []), to: Kuddle.V2.Encoder

  @doc """
  Select allows searching a document for particular nodes by name, and or attributes.

  ## Usage

      Kuddle.select(kdl_document, path)
      [%Kuddle.Node{name: "node"}] = Kuddle.select(document, ["node"])

  ## Examples

      iex> document = Kuddle.decode!("node; node2; node3")
      [%Kuddle.Node{name: "node"}, %Kuddle.Node{name: "node2"}, %Kuddle.Node{name: "node3"}]
      iex> Kuddle.select(document, ["node"])
      [%Kuddle.Node{name: "node"}]

  """
  @spec select(document(), Kuddle.Path.path()) :: document()
  defdelegate select(doc, path), to: Kuddle.Path
end

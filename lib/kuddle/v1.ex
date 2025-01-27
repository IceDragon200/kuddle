defmodule Kuddle.V1 do
  @moduledoc """
  Kuddle is a KDL (https://github.com/kdl-org/kdl) encoder and decoder.

  Kuddle is KDL 1.0.0 compliant and should be able to process most if not all KDL documents without
  issue.

  And yes UTF-8 works.
  """
  @type document :: Kuddle.V1.Decoder.document()

  @type tokens :: Kuddle.V1.Tokenizer.tokens()

  @doc """
  Decode a KDL document into kuddle nodes

  ## Usage

      {:ok, [%Kuddle.Node{name: "node"}], []} = Kuddle.V1.decode("node")

  ## Examples

      iex> Kuddle.V1.decode("node { node2 1; }")
      {:ok, [%Kuddle.Node{name: "node", children: [%Kuddle.Node{name: "node2", attributes: [%Kuddle.Value{type: :integer, value: 1, format: :dec}]}]}], []}

  """
  @spec decode(String.t()) ::
          {:ok, document(), rest::tokens()}
          | {:error, term()}
  defdelegate decode(blob), to: Kuddle.V1.Decoder

  @doc """
  Decode a KDL blob into kuddle nodes, if the blob is not a valid KDL document this will raise
  a Kuddle.DecodeError.

  ## Usage

      [%Kuddle.Node{name: "node"}] = Kuddle.V1.decode!("node")

  ## Examples

      iex> Kuddle.V1.decode!("node")
      [%Kuddle.Node{name: "node"}]

  """
  @spec decode!(String.t()) :: document()
  defdelegate decode!(blob), to: Kuddle.V1.Decoder

  @doc """
  Encode a kuddle document as serialized KDL

  ## Usage

      {:ok, "node"} = Kuddle.V1.encode([%Kuddle.Node{name: "node"}])

  ## Examples

      iex> Kuddle.V1.encode([%Kuddle.Node{name: "node"}])
      {:ok, "node\\n"}

  """
  @spec encode(document()) ::
          {:ok, String.t()}
          | {:error, term()}
  defdelegate encode(doc), to: Kuddle.V1.Encoder

  @doc """
  Encode a kuddle document as serialized KDL, if the document cannot be encoded a Kuddle.EncodeError
  will be raised.

  ## Usage

      "node" = Kuddle.V1.encode!([%Kuddle.Node{name: "node"}])

  ## Examples

      iex> Kuddle.V1.encode!([%Kuddle.Node{name: "node"}])
      "node\\n"

  """
  @spec encode!(document()) :: String.t()
  defdelegate encode!(doc), to: Kuddle.V1.Encoder

  @doc """
  Select allows searching a document for particular nodes by name, and or attributes.

  ## Usage

      [%Kuddle.Node{name: "node"}] = Kuddle.V1.select(document, ["node"])

  ## Examples

      iex> document = Kuddle.V1.decode!("node; node2; node3")
      [%Kuddle.Node{name: "node"}, %Kuddle.Node{name: "node2"}, %Kuddle.Node{name: "node3"}]
      iex> Kuddle.V1.select(document, ["node"])
      [%Kuddle.Node{name: "node"}]

  """
  @spec select(document(), Kuddle.Path.path()) :: document()
  defdelegate select(doc, path), to: Kuddle.Path
end

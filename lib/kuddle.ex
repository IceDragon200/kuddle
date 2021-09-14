defmodule Kuddle do
  @moduledoc """
  Kuddle is a KDL (https://github.com/kdl-org/kdl) encoder and decoder.
  """
  @type document :: Kuddle.Decoder.document()

  @spec decode(String.t()) ::
          {:ok, document(), rest::String.t()}
          | {:error, term()}
  defdelegate decode(blob), to: Kuddle.Decoder

  @spec encode(document()) ::
          {:ok, String.t()}
          | {:error, term()}
  defdelegate encode(doc), to: Kuddle.Encoder

  @doc """
  Select allows searching a document list for particular nodes by name, attributes or name and
  attribute.
  """
  @spec select(document(), Kuddle.Path.path()) :: document()
  defdelegate select(doc, path), to: Kuddle.Path
end

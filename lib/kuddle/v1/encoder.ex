defmodule Kuddle.V1.Encoder do
  @moduledoc """
  Encodes a Kuddle document into a KDL blob
  """
  alias Kuddle.Value
  alias Kuddle.Node

  import Kuddle.V1.Utils

  @type document :: Kuddle.V1.Decoder.document()

  @doc """
  Same as encode/1,2, but will raise a Kuddle.EncodeError on error from decode.

  The options argument is discarded as options is a V2 feature.
  """
  @spec encode!(document(), Keyword.t()) :: String.t()
  def encode!(document, _options \\ []) do
    case encode(document) do
      {:ok, blob} ->
        blob

      {:error, reason} ->
        raise Kuddle.EncodeError, reason: reason
    end
  end

  @doc """
  Encodes a kuddle document as a KDL string
  """
  @spec encode(document()) ::
          {:ok, String.t()}
          | {:error, term()}
  def encode([]) do
    {:ok, "\n"}
  end

  def encode(doc) do
    case do_encode(doc, []) do
      {:ok, rows} ->
        {:ok, IO.iodata_to_binary(rows)}

      {:error, _reason} = err ->
        err
    end
  end

  defp do_encode([], rows) do
    {:ok, Enum.reverse(rows)}
  end

  defp do_encode([%Node{name: name, attributes: attrs, children: nil} | rest], rows) do
    node_name = encode_node_name(name)

    result = [node_name]

    result =
      case encode_node_attributes(attrs, []) do
        [] ->
          result

        node_attrs ->
          [result, " ", Enum.intersperse(node_attrs, " ")]
      end

    do_encode(rest, [[result, "\n"] | rows])
  end

  defp do_encode([%Node{name: name, attributes: attrs, children: children} | rest], rows) do
    node_name = encode_node_name(name)

    result = [node_name]

    result =
      case encode_node_attributes(attrs, []) do
        [] ->
          result

        node_attrs ->
          [result, " ", Enum.intersperse(node_attrs, " ")]
      end

    result = [result, " {\n"]
    result =
      case children do
        [] ->
          result

        children ->
          case do_encode(children, []) do
            {:ok, rows} ->
              [
                result,
                indent(rows, "    "),
                "\n",
              ]
          end
      end

    result = [result, "}\n"]

    do_encode(rest, [result | rows])
  end

  defp encode_node_attributes([%Value{} = value | rest], acc) do
    encode_node_attributes(rest, [encode_value(value) | acc])
  end

  defp encode_node_attributes([{%Value{} = key, %Value{} = value} | rest], acc) do
    result = [encode_value(key), "=", encode_value(value)]
    encode_node_attributes(rest, [result | acc])
  end

  defp encode_node_attributes([], acc) do
    Enum.reverse(acc)
  end

  defp encode_value(%Value{value: nil}) do
    "null"
  end

  defp encode_value(%Value{type: :boolean, value: value}) when is_boolean(value) do
    Atom.to_string(value)
  end

  defp encode_value(%Value{type: :string, value: value}) when is_binary(value) do
    encode_string(value)
  end

  defp encode_value(%Value{type: :integer, value: value, format: format}) when is_integer(value) and value >= 0 do
    case format do
      :bin ->
        ["0b", Integer.to_string(value, 2)]

      :oct ->
        ["0o", Integer.to_string(value, 8)]

      :dec ->
        Integer.to_string(value, 10)

      :hex ->
        ["0x", String.downcase(Integer.to_string(value, 16))]
    end
  end

  defp encode_value(%Value{type: :integer, value: value, format: format}) when is_integer(value) and value < 0 do
    case format do
      :bin ->
        ["-0b", Integer.to_string(-value, 2)]

      :oct ->
        ["-0o", Integer.to_string(-value, 8)]

      :dec ->
        Integer.to_string(value, 10)

      :hex ->
        ["-0x", String.downcase(Integer.to_string(-value, 16))]
    end
  end

  defp encode_value(%Value{type: :float, value: value}) when is_float(value) do
    String.upcase(Float.to_string(value))
  end

  defp encode_value(%Value{type: :float, value: %Decimal{} = value}) do
    String.upcase(Decimal.to_string(value, :scientific))
  end

  defp encode_value(%Value{type: :id, value: value}) when is_binary(value) do
    value
  end

  defp encode_string(str) do
    "\"" <> do_encode_string(str, []) <> "\""
  end

  defp do_encode_string(<<>>, acc) do
    IO.iodata_to_binary(Enum.reverse(acc))
  end

  defp do_encode_string(<<"/", rest::binary>>, acc) do
    do_encode_string(rest, ["\\/" | acc])
  end

  defp do_encode_string(<<"\\", rest::binary>>, acc) do
    do_encode_string(rest, ["\\\\" | acc])
  end

  defp do_encode_string(<<"\"", rest::binary>>, acc) do
    do_encode_string(rest, ["\\\"" | acc])
  end

  defp do_encode_string(<<"\b", rest::binary>>, acc) do
    do_encode_string(rest, ["\\b" | acc])
  end

  defp do_encode_string(<<"\f", rest::binary>>, acc) do
    do_encode_string(rest, ["\\f" | acc])
  end

  defp do_encode_string(<<"\r", rest::binary>>, acc) do
    do_encode_string(rest, ["\\r" | acc])
  end

  defp do_encode_string(<<"\n", rest::binary>>, acc) do
    do_encode_string(rest, ["\\n" | acc])
  end

  defp do_encode_string(<<"\t", rest::binary>>, acc) do
    do_encode_string(rest, ["\\t" | acc])
  end

  defp do_encode_string(<<c::utf8, rest::binary>>, acc) do
    do_encode_string(rest, [<<c::utf8>> | acc])
  end

  defp encode_node_name(name) do
    if valid_identifier?(name) and not need_quote?(name) do
      name
    else
      encode_string(name)
    end
  end

  defp indent(rows, spacer) do
    rows
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
    |> String.split("\n")
    |> Enum.map(fn row ->
      [spacer, row]
    end)
    |> Enum.intersperse("\n")
  end
end

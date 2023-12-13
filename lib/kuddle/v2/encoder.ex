defmodule Kuddle.V2.Encoder do
  @moduledoc """
  Encodes a Kuddle document into a KDL blob
  """
  alias Kuddle.Value
  alias Kuddle.Node

  import Kuddle.V2.Utils

  @type document :: Kuddle.V2.Decoder.document()

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

      {:error, _} = err ->
        err
    end
  end

  defp do_encode([], rows) do
    {:ok, Enum.reverse(rows)}
  end

  defp do_encode([%Node{name: name, attributes: attrs, children: nil} | rest], rows) do
    {:ok, node_name} = encode_node_name(name)

    result = [node_name]

    result =
      case encode_node_attributes(attrs, []) do
        {:ok, []} ->
          result

        {:ok, node_attrs} ->
          [result, " ", Enum.intersperse(node_attrs, " ")]
      end

    do_encode(rest, [[result, "\n"] | rows])
  end

  defp do_encode([%Node{name: name, attributes: attrs, children: children} | rest], rows) do
    {:ok, node_name} = encode_node_name(name)

    result = [node_name]

    result =
      case encode_node_attributes(attrs, []) do
        {:ok, []} ->
          result

        {:ok, node_attrs} ->
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
    case encode_value(value) do
      {:ok, value} ->
        encode_node_attributes(rest, [value | acc])

      {:error, _} = err ->
        err
    end
  end

  defp encode_node_attributes([{%Value{} = key, %Value{} = value} | rest], acc) do
    with {:ok, key} <- encode_value(key),
      {:ok, value} <- encode_value(value)
    do
      result = [key, "=", value]
      encode_node_attributes(rest, [result | acc])
    else
      {:error, _} = err ->
        err
    end
  end

  defp encode_node_attributes([], acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp encode_value(%Value{value: nil}) do
    {:ok, "#null"}
  end

  defp encode_value(%Value{type: :boolean, value: value}) when is_boolean(value) do
    {:ok, "#" <> Atom.to_string(value)}
  end

  defp encode_value(%Value{type: :keyword, value: value}) when is_binary(value) do
    if need_quote?(value) do
      {:error, :invalid_keyword}
    else
      {:ok, "##{value}"}
    end
  end

  defp encode_value(%Value{type: :string, value: value}) when is_binary(value) do
    encode_string(value)
  end

  defp encode_value(%Value{type: :integer, value: value, format: format}) when is_integer(value) and value >= 0 do
    case format do
      :bin ->
        {:ok, ["0b", Integer.to_string(value, 2)]}

      :oct ->
        {:ok, ["0o", Integer.to_string(value, 8)]}

      :dec ->
        {:ok, Integer.to_string(value, 10)}

      :hex ->
        {:ok, ["0x", String.downcase(Integer.to_string(value, 16))]}
    end
  end

  defp encode_value(%Value{type: :integer, value: value, format: format}) when is_integer(value) and value < 0 do
    case format do
      :bin ->
        {:ok, ["-0b", Integer.to_string(-value, 2)]}

      :oct ->
        {:ok, ["-0o", Integer.to_string(-value, 8)]}

      :dec ->
        {:ok, Integer.to_string(value, 10)}

      :hex ->
        {:ok, ["-0x", String.downcase(Integer.to_string(-value, 16))]}
    end
  end

  defp encode_value(%Value{type: :float, value: value}) when is_float(value) do
    {:ok, String.upcase(Float.to_string(value))}
  end

  defp encode_value(%Value{type: :float, value: %Decimal{} = value}) do
    {:ok, String.upcase(Decimal.to_string(value, :scientific))}
  end

  defp encode_value(%Value{type: :id, value: value}) when is_binary(value) do
    {:ok, value}
  end

  defp encode_string(str) do
    {:ok, "\"" <> do_encode_string(str, []) <> "\""}
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

  defp do_encode_string(<<"\v", rest::binary>>, acc) do
    do_encode_string(rest, ["\\v" | acc])
  end

  defp do_encode_string(<<c::utf8, rest::binary>>, acc) do
    do_encode_string(rest, [<<c::utf8>> | acc])
  end

  defp encode_node_name(name) do
    if valid_identifier?(name) and not need_quote?(name) do
      {:ok, name}
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

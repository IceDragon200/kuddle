defmodule Kuddle.Encoder do
  alias Kuddle.Value

  def encode([]) do
    {:ok, "\n"}
  end

  def encode(doc) do
    case do_encode(doc, []) do
      {:ok, rows} ->
        {:ok, IO.iodata_to_binary(rows)}
    end
  end

  defp do_encode([], rows) do
    {:ok, Enum.reverse(rows)}
  end

  defp do_encode([{:node, name, values, nil} | rest], rows) do
    node_name = encode_node_name(name)

    result = [node_name]

    result =
      case encode_node_values(values, []) do
        [] ->
          result

        node_values ->
          [result, " ", Enum.intersperse(node_values, " ")]
      end

    do_encode(rest, [[result, "\n"] | rows])
  end

  defp do_encode([{:node, name, values, children} | rest], rows) do
    node_name = encode_node_name(name)

    result = [node_name]

    result =
      case encode_node_values(values, []) do
        [] ->
          result

        node_values ->
          [result, " ", Enum.intersperse(node_values, " ")]
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

  defp encode_node_values([%Value{} = value | rest], acc) do
    encode_node_values(rest, [value_to_string(value) | acc])
  end

  defp encode_node_values([], acc) do
    Enum.reverse(acc)
  end

  defp value_to_string(%Value{value: nil}) do
    "null"
  end

  defp value_to_string(%Value{type: :boolean, value: value}) when is_boolean(value) do
    Atom.to_string(value)
  end

  defp value_to_string(%Value{type: :string, value: value}) when is_binary(value) do
    encode_string(value)
  end

  defp value_to_string(%Value{type: :integer, value: value, format: format}) when is_integer(value) do
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

  defp value_to_string(%Value{type: :float, value: value}) when is_float(value) do
    Float.to_string(value)
  end

  defp encode_string(str) do
    "\"" <> do_encode_string(str, []) <> "\""
  end

  defp do_encode_string(<<>>, acc) do
    IO.iodata_to_binary(Enum.reverse(acc))
  end

  defp do_encode_string(<<"\\", rest::binary>>, acc) do
    do_encode_string(rest, ["\\\\" | acc])
  end

  defp do_encode_string(<<"\"", rest::binary>>, acc) do
    do_encode_string(rest, ["\\\"" | acc])
  end

  defp do_encode_string(<<"\n", rest::binary>>, acc) do
    do_encode_string(rest, ["\\n" | acc])
  end

  defp do_encode_string(<<c::utf8, rest::binary>>, acc) do
    do_encode_string(rest, [<<c::utf8>> | acc])
  end

  defp encode_node_name(name) do
    if name =~ ~r/\A[a-zA-Z][a-zA-Z0-9]*\z/ do
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

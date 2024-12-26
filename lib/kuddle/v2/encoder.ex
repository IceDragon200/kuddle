defmodule Kuddle.V2.Encoder do
  @moduledoc """
  Encodes a Kuddle document into a KDL blob
  """
  alias Kuddle.Value
  alias Kuddle.Node

  import Kuddle.Utils
  import Kuddle.V2.Utils

  @type document :: Kuddle.V2.Decoder.document()

  @doc """
  Encodes a kuddle document as a KDL string
  """
  @spec encode(document(), Keyword.t()) ::
          {:ok, String.t()}
          | {:error, term()}
  def encode(document, options \\ [])

  def encode([], _options) do
    {:ok, "\n"}
  end

  def encode(doc, options) do
    case do_encode(doc, [], options) do
      {:ok, rows} ->
        {:ok, IO.iodata_to_binary(rows)}

      {:error, _} = err ->
        err
    end
  end

  defp do_encode([], rows, _options) do
    {:ok, Enum.reverse(rows)}
  end

  defp do_encode(
    [%Node{name: name, attributes: attrs, children: children, annotations: annotations} | rest],
    rows,
    options
  ) do
    {:ok, node_name} = encode_node_name(name, options)

    result =
      case annotations do
        [] ->
          [node_name]

        [annotation] ->
          {:ok, annotation} = encode_annotation(annotation)

          ["(", annotation, ")", node_name]
      end

    result =
      case encode_node_attributes(attrs, [], options) do
        {:ok, []} ->
          result

        {:ok, node_attrs} ->
          [result, " ", Enum.intersperse(node_attrs, " ")]
      end

    result =
      case children do
        nil ->
          [result, "\n"]

        [] ->
          [result, "\n"]

        list when is_list(list) ->
          result = [result, " {\n"]
          result =
            case children do
              [] ->
                result

              children ->
                case do_encode(children, [], options) do
                  {:ok, rows} ->
                    [
                      result,
                      indent(rows, "    "),
                      "\n",
                    ]
                end
            end

          [result, "}\n"]
      end

    do_encode(rest, [result | rows], options)
  end

  defp encode_node_attributes([%Value{} = value | rest], acc, options) do
    case encode_value(value, options) do
      {:ok, value} ->
        encode_node_attributes(rest, [value | acc], options)

      {:error, _} = err ->
        err
    end
  end

  defp encode_node_attributes([{%Value{} = key, %Value{} = value} | rest], acc, options) do
    with {:ok, key} <- encode_value(key, options),
      {:ok, value} <- encode_value(value, options)
    do
      result = [key, "=", value]
      encode_node_attributes(rest, [result | acc], options)
    else
      {:error, _} = err ->
        err
    end
  end

  defp encode_node_attributes([], acc, _options) do
    {:ok, Enum.reverse(acc)}
  end

  defp encode_value(%Value{annotations: []} = value, options) do
    encode_value_value(value, options)
  end

  defp encode_value(%Value{annotations: [annotation | _]} = value, options) do
    case encode_value_value(value, options) do
      {:ok, value} ->
        {:ok, annotation} = encode_annotation(annotation)

        {:ok, ["(", annotation, ")", value]}
    end
  end

  defp encode_value_value(%Value{value: nil}, _options) do
    {:ok, "#null"}
  end

  defp encode_value_value(%Value{type: :nan, value: :nan}, _options) do
    {:ok, "#nan"}
  end

  defp encode_value_value(%Value{type: :boolean, value: value}, _options) when is_boolean(value) do
    {:ok, "#" <> Atom.to_string(value)}
  end

  defp encode_value_value(%Value{type: :infinity, value: :infinity}, _options) do
    {:ok, "#inf"}
  end

  defp encode_value_value(%Value{type: :infinity, value: :'-infinity'}, _options) do
    {:ok, "#-inf"}
  end

  defp encode_value_value(%Value{type: :keyword, value: value}, _options) when is_binary(value) do
    if need_quote?(value) do
      {:error, :invalid_keyword}
    else
      {:ok, "##{value}"}
    end
  end

  defp encode_value_value(%Value{type: :string, value: value}, options) when is_binary(value) do
    encode_string(value, options)
  end

  defp encode_value_value(
    %Value{type: :integer, value: value, format: format},
    options
  ) when is_integer(value) and value >= 0 do
    preferred_format = Keyword.get(options, :integer_format, format)
    case preferred_format do
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

  defp encode_value_value(
    %Value{type: :integer, value: value, format: format},
    options
  ) when is_integer(value) and value < 0 do
    preferred_format = Keyword.get(options, :integer_format, format)
    case preferred_format do
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

  defp encode_value_value(%Value{type: :float, value: value}, _options) when is_float(value) do
    {:ok, String.upcase(Float.to_string(value))}
  end

  defp encode_value_value(%Value{type: :float, value: %Decimal{} = value}, _options) do
    {:ok, String.upcase(Decimal.to_string(value, :scientific))}
  end

  defp encode_value_value(%Value{type: :id, value: value}, _options) when is_binary(value) do
    {:ok, value}
  end

  defp encode_string(str, options) do
    if need_quote?(str) do
      {:ok, "\"" <> do_encode_string(str, [], options) <> "\""}
    else
      {:ok, str}
    end
  end

  defp do_encode_string(<<>>, acc, _options) do
    IO.iodata_to_binary(Enum.reverse(acc))
  end

  defp do_encode_string(<<"\\", rest::binary>>, acc, options) do
    do_encode_string(rest, ["\\\\" | acc], options)
  end

  defp do_encode_string(<<"\"", rest::binary>>, acc, options) do
    do_encode_string(rest, ["\\\"" | acc], options)
  end

  defp do_encode_string(<<"\b", rest::binary>>, acc, options) do
    do_encode_string(rest, ["\\b" | acc], options)
  end

  defp do_encode_string(<<"\f", rest::binary>>, acc, options) do
    do_encode_string(rest, ["\\f" | acc], options)
  end

  defp do_encode_string(<<"\r", rest::binary>>, acc, options) do
    do_encode_string(rest, ["\\r" | acc], options)
  end

  defp do_encode_string(<<"\n", rest::binary>>, acc, options) do
    do_encode_string(rest, ["\\n" | acc], options)
  end

  defp do_encode_string(<<"\t", rest::binary>>, acc, options) do
    do_encode_string(rest, ["\\t" | acc], options)
  end

  defp do_encode_string(<<"\v", rest::binary>>, acc, options) do
    do_encode_string(rest, ["\\v" | acc], options)
  end

  defp do_encode_string(
    <<c::utf8, rest::binary>>,
    acc,
    options
  ) when c < 0x20 or
    is_utf8_disallowed_char(c) or
    is_utf8_newline_like_char(c) or
    is_utf8_bom_char(c) or
    not is_utf8_scalar_char(c)
  do
    do_encode_string(rest, ["\\u{#{encode_unicode(c)}}" | acc], options)
  end

  defp do_encode_string(<<c::utf8, rest::binary>>, acc, options) when is_utf8_scalar_char(c) do
    do_encode_string(rest, [<<c::utf8>> | acc], options)
  end

  defp encode_node_name(name, options) when is_binary(name) do
    if valid_identifier?(name) and not need_quote?(name) do
      {:ok, name}
    else
      encode_string(name, options)
    end
  end

  defp encode_annotation(val, options \\ []) when is_binary(val) do
    if need_quote?(val) do
      encode_string(val, options)
    else
      {:ok, val}
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

  defp encode_unicode(c) do
    Integer.to_string(c, 16)
  end
end

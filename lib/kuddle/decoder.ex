defmodule Kuddle.Decoder do
  alias Kuddle.Value

  import Kuddle.Tokenizer

  def decode(blob) when is_binary(blob) do
    case tokenize(blob) do
      {:ok, tokens} ->
        parse(tokens)

      {:error, _} = err ->
        err
    end
  end

  defp parse(tokens) do
    do_parse(tokens, {:default, 0}, nil, [])
  end

  defp do_parse([], {:default, 0}, nil, doc) do
    handle_parse_exit([], doc)
  end

  defp do_parse([{:slashdash, _} | tokens], {:default, _} = state, nil, doc) do
    # add the slashdash to the document accumulator
    # when the next parse is done, the slashdash will cause the next item in the accumulator to
    # be dropped
    do_parse(tokens, state, nil, [:slashdash | doc])
  end

  defp do_parse([{:comment, _} | tokens], {:default, _} = state, nil, doc) do
    do_parse(tokens, state, nil, doc)
  end

  defp do_parse([{:fold, _} | tokens], {:default, _} = state, nil, doc) do
    do_parse(fold_leading_tokens(tokens), state, nil, doc)
  end

  defp do_parse([{:sc, _} | tokens], {:default, _} = state, nil, doc) do
    # loose semi-colon
    do_parse(tokens, state, nil, doc)
  end

  defp do_parse([{:nl, _} | tokens], {:default, _} = state, nil, doc) do
    # trim leading newlines
    do_parse(tokens, state, nil, doc)
  end

  defp do_parse([{:space, _} | tokens], {:default, _} = state, nil, doc) do
    # trim leading space
    do_parse(tokens, state, nil, doc)
  end

  defp do_parse([{:term, name} | tokens], {:default, depth}, nil, doc) do
    # node
    do_parse(tokens, {:node, depth}, {name, []}, doc)
  end

  defp do_parse([{:dquote_string, name} | tokens], {:default, depth}, nil, doc) do
    # double quote initiated node
    do_parse(tokens, {:node, depth}, {name, []}, doc)
  end

  defp do_parse([{:raw_string, name} | tokens], {:default, depth}, nil, doc) do
    # raw string node
    do_parse(tokens, {:node, depth}, {name, []}, doc)
  end

  defp do_parse([{:slashdash, _} | tokens], {:node, _} = state, {name, acc}, doc) do
    do_parse(tokens, state, {name, [:slashdash | acc]}, doc)
  end

  defp do_parse([{:comment, _} | tokens], {:node, _} = state, {name, acc}, doc) do
    # trim comments
    do_parse(tokens, state, {name, acc}, doc)
  end

  defp do_parse([{:space, _} | tokens], {:node, _} = state, {name, acc}, doc) do
    # trim leading spaces in node
    do_parse(tokens, state, {name, acc}, doc)
  end

  defp do_parse([{:fold, _} | tokens], {:node, _} = state, {_name, _acc} = acc, doc) do
    do_parse(fold_leading_tokens(tokens), state, acc, doc)
  end

  defp do_parse([{:nl, _} | tokens], {:node, depth}, {name, acc}, doc) do
    do_parse(tokens, {:default, depth}, nil, [{:node, name, resolve_node_values(acc), nil} | doc])
  end

  defp do_parse([{:sc, _} | tokens], {:node, depth}, {name, acc}, doc) do
    do_parse(tokens, {:default, depth}, nil, [{:node, name, resolve_node_values(acc), nil} | doc])
  end

  defp do_parse([{:open_block, _} | tokens], {:node, depth}, {name, acc}, doc) do
    case do_parse(tokens, {:default, depth + 1}, nil, []) do
      {:ok, children, tokens} ->
        case trim_leading_space(tokens) do
          [{:close_block, _} | tokens] ->
            node =
              case acc do
                [:slashdash | acc] ->
                  # discard the children
                  {:node, name, resolve_node_values(acc), nil}

                acc ->
                  {:node, name, resolve_node_values(acc), children}
              end

            do_parse(tokens, {:default, depth}, nil, [node | doc])
        end

      {:error, _} = err ->
        err
    end
  end

  defp do_parse([token | tokens], {:node, _} = state, {name, acc}, doc) do
    case token_to_value(token) do
      {:ok, key} ->
        case trim_leading_space(tokens) do
          [{:=, _} | tokens] ->
            [token | tokens] = trim_leading_space(tokens)
            case token_to_value(token) do
              {:ok, value} ->
                do_parse(tokens, state, {name, [{key, value} | acc]}, doc)

            end

          tokens ->
            do_parse(tokens, state, {name, [key | acc]}, doc)
        end

      {:error, _} = err ->
        err
    end
  end

  defp do_parse([], {:node, depth}, {name, acc}, doc) do
    do_parse([], {:default, depth}, nil, [{:node, name, resolve_node_values(acc), nil} | doc])
  end

  defp do_parse([{:close_block, _} | _tokens] = tokens, {:default, _depth}, nil, doc) do
    handle_parse_exit(tokens, doc)
  end

  defp handle_parse_exit(rest, doc) do
    doc = Enum.reverse(doc)

    {:ok, handle_slashdashes(doc, []), rest}
  end

  defp resolve_node_values(acc) do
    handle_slashdashes(Enum.reverse(acc), [])
  end

  defp fold_leading_tokens([{:space, _} | tokens]) do
    fold_leading_tokens(tokens)
  end

  defp fold_leading_tokens([{:nl, _} | tokens]) do
    fold_leading_tokens(tokens)
  end

  defp fold_leading_tokens(tokens) do
    tokens
  end

  defp trim_leading_space([{:space, _} | tokens]) do
    trim_leading_space(tokens)
  end

  defp trim_leading_space(tokens) do
    tokens
  end

  defp token_to_value({:term, value}) do
    decode_term(value)
  end

  defp token_to_value({:dquote_string, value}) do
    {:ok, %Value{value: value, type: :string}}
  end

  defp token_to_value({:raw_string, value}) do
    {:ok, %Value{value: value, type: :string}}
  end

  defp decode_term("true") do
    {:ok, %Value{value: true, type: :boolean}}
  end

  defp decode_term("false") do
    {:ok, %Value{value: false, type: :boolean}}
  end

  defp decode_term("null") do
    {:ok, %Value{value: nil}}
  end

  defp decode_term(<<"0b", rest::binary>>) do
    decode_bin_integer(rest, [])
  end

  defp decode_term(<<"0o", rest::binary>>) do
    decode_oct_integer(rest, [])
  end

  defp decode_term(<<"0x", rest::binary>>) do
    decode_hex_integer(rest, [])
  end

  defp decode_term(<<".", c::utf8, _rest::binary>> = value) when c in ?0..?9 do
    decode_float("0" <> value)
  end

  defp decode_term(term) do
    case decode_dec_integer(term, []) do
      {:ok, value} ->
        {:ok, value}

      {:error, _} ->
        case decode_float(term) do
          {:ok, value} ->
            {:ok, value}

          {:error, _} ->
            {:ok, %Value{value: term, type: :id}}
        end
    end
  end

  defp decode_bin_integer(<<"_", rest::binary>>, acc) do
    decode_bin_integer(rest, acc)
  end

  defp decode_bin_integer(<<c::utf8, rest::binary>>, acc) when c in [?0, ?1, ?+, ?-] do
    decode_bin_integer(rest, [<<c::utf8>> | acc])
  end

  defp decode_bin_integer(<<_::utf8, _rest::binary>>, _acc) do
    {:error, :invalid_bin_integer_format}
  end

  defp decode_bin_integer(<<>>, acc) do
    case decode_integer(acc, 2) do
      {:ok, value} ->
        {:ok, %{value | format: :bin}}

      {:error, _} = err ->
        err
    end
  end

  defp decode_oct_integer(<<"_", rest::binary>>, acc) do
    decode_oct_integer(rest, acc)
  end

  defp decode_oct_integer(<<c::utf8, rest::binary>>, acc) when c in ?0..?7 or c in [?+, ?-] do
    decode_oct_integer(rest, [<<c::utf8>> | acc])
  end

  defp decode_oct_integer(<<_::utf8, _rest::binary>>, _acc) do
    {:error, :invalid_oct_integer_format}
  end

  defp decode_oct_integer(<<>>, acc) do
    case decode_integer(acc, 8) do
      {:ok, value} ->
        {:ok, %{value | format: :oct}}

      {:error, _} = err ->
        err
    end
  end

  defp decode_dec_integer(<<"_", rest::binary>>, acc) do
    decode_dec_integer(rest, acc)
  end

  defp decode_dec_integer(<<c::utf8, rest::binary>>, acc) when c in ?0..?9 or c in [?+, ?-] do
    decode_dec_integer(rest, [<<c::utf8>> | acc])
  end

  defp decode_dec_integer(<<_::utf8, _rest::binary>>, _acc) do
    {:error, :invalid_dec_integer_format}
  end

  defp decode_dec_integer(<<>>, acc) do
    case decode_integer(acc, 10) do
      {:ok, value} ->
        {:ok, %{value | format: :dec}}

      {:error, _} = err ->
        err
    end
  end

  defp decode_hex_integer(<<"_", rest::binary>>, acc) do
    decode_hex_integer(rest, acc)
  end

  defp decode_hex_integer(<<c::utf8, rest::binary>>, acc) when c in ?0..?9 or
                                                               c in ?A..?F or
                                                               c in ?a..?f or
                                                               c in [?+, ?-] do
    decode_hex_integer(rest, [<<c::utf8>> | acc])
  end

  defp decode_hex_integer(<<_::utf8, _rest::binary>>, _acc) do
    {:error, :invalid_oct_integer_format}
  end

  defp decode_hex_integer(<<>>, acc) do
    case decode_integer(acc, 16) do
      {:ok, value} ->
        {:ok, %{value | format: :hex}}

      {:error, _} = err ->
        err
    end
  end

  defp decode_integer(acc, radix) do
    case Integer.parse(IO.iodata_to_binary(Enum.reverse(acc)), radix) do
      {int, ""} ->
        {:ok, %Value{value: int, type: :integer}}

      {_int, _} ->
        {:error, :invalid_integer_format}

      :error ->
        {:error, :invalid_integer_format}
    end
  end

  defp decode_float(value) do
    case decode_float_string(value, :start, []) do
      {:ok, value} ->
        case Float.parse(value) do
          {flt, ""} ->
            {:ok, %Value{value: flt, type: :float}}

          {_flt, _} ->
            {:error, :invalid_float_format}

          :error ->
            {:error, :invalid_float_format}
        end

      {:error, _} = err ->
        err
    end
  end

  defp handle_slashdashes([:slashdash, _term | tokens], acc) do
    handle_slashdashes(tokens, acc)
  end

  defp handle_slashdashes([:slashdash], acc) do
    handle_slashdashes([], acc)
  end

  defp handle_slashdashes([term | tokens], acc) do
    handle_slashdashes(tokens, [term | acc])
  end

  defp handle_slashdashes([], acc) do
    Enum.reverse(acc)
  end

  defp decode_float_string(<<>>, _, acc) do
    {:ok, IO.iodata_to_binary(Enum.reverse(acc))}
  end

  defp decode_float_string(<<c::utf8, rest::binary>>, :start, acc) when c == ?- or
                                                                        c == ?+  do
    decode_float_string(rest, :start_number, [<<c::utf8>> | acc])
  end

  defp decode_float_string(<<c::utf8, rest::binary>>, state, acc) when c in ?0..?9 and state in [:start, :start_number, :body] do
    decode_float_string(rest, :body, [<<c::utf8>> | acc])
  end

  defp decode_float_string(<<".", rest::binary>>, :body, acc) do
    decode_float_string(rest, :body, [<<".">> | acc])
  end

  defp decode_float_string(<<"_", rest::binary>>, :body, acc) do
    decode_float_string(rest, :body, acc)
  end

  defp decode_float_string(<<"E", rest::binary>>, :body, acc) do
    decode_float_string(rest, :start_exponent, [<<"E">> | acc])
  end

  defp decode_float_string(<<c::utf8, rest::binary>>, :start_exponent, acc) when c == ?- or
                                                                                 c == ?+  do
    decode_float_string(rest, :exponent, [<<c::utf8>> | acc])
  end

  defp decode_float_string(<<c::utf8, rest::binary>>, state, acc) when c in ?0..?9 and state in [:start_exponent, :exponent] do
    decode_float_string(rest, :exponent, [<<c::utf8>> | acc])
  end

  defp decode_float_string(<<"_", rest::binary>>, :exponent, acc) do
    decode_float_string(rest, :exponent, acc)
  end

  defp decode_float_string(_, _state, _acc) do
    {:error, :unexpected_characters}
  end
end

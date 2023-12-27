defmodule Kuddle.V2.Utils do
  import Kuddle.Utils

  @type char_or_code :: binary() | integer()

  @type esc_multiline :: {:esc | :uesc, [char_or_code()]}

  defguard is_utf8_space_like_char(c) when c in [
    0x09,
    0x0B,
    # Whitespace
    0x20,
    # No-Break Space
    0xA0,
    # Ogham Space Mark
    0x1680,
    # En Quad
    0x2000,
    # Em Quad
    0x2001,
    # En Space
    0x2002,
    # Em Space
    0x2003,
    # Three-Per-Em Space
    0x2004,
    # Four-Per-Em Space
    0x2005,
    # Six-Per-Em Space
    0x2006,
    # Figure Space
    0x2007,
    # Punctuation Space
    0x2008,
    # Thin Space
    0x2009,
    # Hair Space
    0x200A,
    # Narrow No-Break Space
    0x202F,
    # Medium Mathematical Space
    0x205F,
    # Ideographic Space
    0x3000,
  ]

  defguard is_utf8_newline_like_char(c) when c in [
    # New Line
    0x0A,
    # NP form feed, new pag
    0x0C,
    # Carriage Return
    0x0D,
    # Next-Line
    0x85,
    # Line Separator
    0x2028,
    # Paragraph Separator
    0x2029,
  ]

  defguard is_utf8_twochar_newline(c1, c2) when c1 == 0x0D and c2 == 0x0A

  defguard is_utf8_equals_like_char(c) when c in [
    ?=,
    0xFE66,
    0xFF1D,
    0x1F7F0,
  ]

  defguard is_utf8_disallowed_char(c) when
    not is_utf8_scalar_char(c) or
    is_utf8_direction_control_char(c)

  defguard is_utf8_non_identifier_char(c) when
    c < 0x20 or
    is_utf8_disallowed_char(c) or
    is_utf8_space_like_char(c) or
    is_utf8_newline_like_char(c) or
    is_utf8_equals_like_char(c) or
    is_utf8_bom_char(c) or
    c in [
      ?(,
      ?),
      ?{,
      ?},
      ?[,
      ?],
      ?/,
      ?\\,
      ?",
      ?#,
      ?;,
    ]

  @doc """
  Variant of list_to_utf8_binary, but specifically for handling multiline strings
  """
  @spec multiline_list_to_utf8_binary(list()) :: {:ok, binary()} | {:error, term()}
  def multiline_list_to_utf8_binary(list) when is_list(list) do
    # need to flatten it first to unroll any sub-lists
    list = List.flatten(list)
    lines = split_multiline_list(list)

    case lines do
      [] ->
        {:ok, ""}

      [{:esc, _} | _lines] ->
        {:error, {:invalid_end_line, :line_contains_escaped_chars}}

      [{:uesc, chars}] ->
        # Handles empty multiline, but with last quote indented, we just determine if the
        # chars are spaces and then dump it
        case multiline_determine_spaces([0x0A | chars]) do
          {:error, reason} ->
            {:error, {:invalid_end_line, reason: reason, line: chars}}

          {:ok, _} ->
            {:ok, ""}
        end

      [{:uesc, chars} | lines] ->
        case multiline_determine_spaces(chars) do
          {:error, reason} ->
            {:error, {:invalid_end_line, reason: reason, line: chars}}

          {:ok, spaces} ->
            result =
              Enum.reduce_while(lines, {:ok, []}, fn {_, line}, {:ok, acc} ->
                case line do
                  [c1, c2 | line] when is_utf8_twochar_newline(c1, c2) ->
                    case dedent_multline_by_spaces(line, spaces) do
                      {:ok, line} ->
                        {:cont, {:ok, [[c1, c2 | line] | acc]}}

                      {:error, reason} ->
                        {:halt, {:error, {reason, line: line}}}
                    end

                  [c | line] when is_utf8_newline_like_char(c) ->
                    case dedent_multline_by_spaces(line, spaces) do
                      {:ok, line} ->
                        {:cont, {:ok, [[c | line] | acc]}}

                      {:error, reason} ->
                        {:halt, {:error, {reason, line: line}}}
                    end

                  line ->
                    case dedent_multline_by_spaces(line, spaces) do
                      {:ok, line} ->
                        {:cont, {:ok, [line | acc]}}

                      {:error, reason} ->
                        {:halt, {:error, {reason, line: line}}}
                    end
                end
              end)

            case result do
              {:error, _reason} = err ->
                err

              {:ok, lines} ->
                # and because we started with the lines reversed, this list is now in the correct
                # order
                {:ok, list_to_utf8_binary(lines)}
            end
        end
    end
  end

  def dedent_multline_by_spaces([c | line], [c | spaces]) do
    dedent_multline_by_spaces(line, spaces)
  end

  def dedent_multline_by_spaces(line, []) do
    {:ok, line}
  end

  def dedent_multline_by_spaces(_, _) do
    {:error, :incomplete_dedentation}
  end

  def multiline_determine_spaces([c1, c2 | chars]) when is_utf8_twochar_newline(c1, c2) do
    do_multiline_determine_spaces(chars)
  end

  def multiline_determine_spaces([c | chars]) when is_utf8_newline_like_char(c) do
    do_multiline_determine_spaces(chars)
  end

  defp do_multiline_determine_spaces(chars, acc \\ [])

  defp do_multiline_determine_spaces([], acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp do_multiline_determine_spaces([c | chars], acc) when is_utf8_space_like_char(c) do
    do_multiline_determine_spaces(chars, [c | acc])
  end

  defp do_multiline_determine_spaces([_c | _chars], _acc) do
    {:error, :expected_spaces}
  end

  @doc """
  Splits a multiline list, this will mark each line with its escape status, a line with a :esc
  status should not be used for whitespace trimming/dedent, as it was explictly set.

  One thing to note is all lines in the returned list start with a newline if its not the
  first line.

  The returned array is always reversed, so the last line will be first
  """
  @spec split_multiline_list([char_or_code()], esc_multiline(), [esc_multiline()]) ::
    [esc_multiline()]
  def split_multiline_list(list, line \\ {:uesc, []}, acc \\ [])

  def split_multiline_list([], {_status, []}, acc) when is_list(acc) do
    acc
  end

  def split_multiline_list([], {status, line}, acc) when is_list(line) and is_list(acc) do
    # commit the last line
    [{status, Enum.reverse(line)} | acc]
  end

  def split_multiline_list([{:esc, c} | list], {_status, line}, acc) do
    # the line contains an escape sequence, lines with escape sequences cannot be used for
    # dedent pattern, so if this is the _last_ line, it will be an error
    split_multiline_list(list, {:esc, [{:esc, c} | line]}, acc)
  end

  def split_multiline_list([c1, c2 | list], {status, line}, acc) when is_utf8_twochar_newline(c1, c2) do
    # CRLF - Carriage Return + Line Feed, standard Windows line ending
    split_multiline_list(list, {:uesc, [c2, c1]}, [{status, Enum.reverse(line)} | acc])
  end

  def split_multiline_list([c | list], {status, line}, acc) when is_utf8_newline_like_char(c) do
    # For everyone else, the single character line endings
    split_multiline_list(list, {:uesc, [c]}, [{status, Enum.reverse(line)} | acc])
  end

  def split_multiline_list([c | list], {status, line}, acc) do
    split_multiline_list(list, {status, [c | line]}, acc)
  end

  @doc """
  Splits off as many space characters as possible
  """
  @spec split_spaces(binary(), list()) :: {spaces::binary(), rest::binary()}
  def split_spaces(rest, acc \\ [])

  def split_spaces(<<>> = rest, acc) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest}
  end

  def split_spaces(<<c::utf8, rest::binary>>, acc) when is_utf8_space_like_char(c) do
    split_spaces(rest, [c | acc])
  end

  def split_spaces(rest, acc) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest}
  end

  def split_spaces_and_newlines(rest, meta, acc \\ [])

  def split_spaces_and_newlines(<<c::utf8, rest::binary>>, meta, acc) when is_utf8_space_like_char(c) do
    split_spaces_and_newlines(rest, add_col(meta, byte_size(<<c::utf8>>)), [c | acc])
  end

  def split_spaces_and_newlines(<<c1::utf8, c2::utf8, rest::binary>>, meta, acc) when is_utf8_twochar_newline(c1, c2) do
    split_spaces_and_newlines(rest, add_line(meta, 1), [c2, c1 | acc])
  end

  def split_spaces_and_newlines(<<c::utf8, rest::binary>>, meta, acc) when is_utf8_newline_like_char(c) do
    split_spaces_and_newlines(rest, add_line(meta, 1), [c | acc])
  end

  def split_spaces_and_newlines(rest, meta, acc) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest, meta}
  end

  @spec split_up_to_newline(binary(), any(), [any()]) :: {:ok, binary(), binary(), meta::any()} | {:error, term()}
  def split_up_to_newline(rest, meta, acc \\ [])

  def split_up_to_newline(<<>> = rest, meta, acc) do
    {:ok, list_to_utf8_binary(Enum.reverse(acc)), rest, meta}
  end

  def split_up_to_newline(
    <<c1::utf8, c2::utf8, _rest::binary>> = rest,
    meta,
    acc
  ) when is_utf8_twochar_newline(c1, c2) do
    {:ok, list_to_utf8_binary(Enum.reverse(acc)), rest, add_line(meta)}
  end

  def split_up_to_newline(
    <<c::utf8, _rest::binary>> = rest,
    meta,
    acc
  ) when is_utf8_newline_like_char(c) do
    {:ok, list_to_utf8_binary(Enum.reverse(acc)), rest, add_line(meta)}
  end

  def split_up_to_newline(
    <<c::utf8, _rest::binary>>,
    _meta,
    _acc
  ) when is_utf8_disallowed_char(c) do
    {:error, {:disallowed_char, c}}
  end

  def split_up_to_newline(
    <<c::utf8, rest::binary>>,
    meta,
    acc
  ) when is_utf8_scalar_char(c) do
    split_up_to_newline(rest, add_col(meta), [c | acc])
  end

  @doc """
  Check if a string is a valid identifier (that is a plain unbroken character sequence)
  """
  @spec valid_identifier?(String.t()) :: boolean()
  def valid_identifier?(str, state \\ :start)

  def valid_identifier?(word, :start) when word in ["true", "false", "null"] do
    false
  end

  def valid_identifier?(<<c::utf8, _rest::binary>>, _) when is_utf8_non_identifier_char(c) do
    false
  end

  def valid_identifier?(
    <<s::utf8, c::utf8, _rest::binary>>,
    :start
  ) when is_utf8_sign_char(s) and is_utf8_digit_char(c) do
    false
  end

  def valid_identifier?(
    <<".", c::utf8, _rest::binary>>,
    :start
  ) when is_utf8_digit_char(c) do
    false
  end

  def valid_identifier?(
    <<c::utf8, _rest::binary>>,
    :start
  ) when is_utf8_digit_char(c) do
    false
  end

  def valid_identifier?(<<_c::utf8, rest::binary>>, _) do
    valid_identifier?(rest, :body)
  end

  def valid_identifier?(<<>>, :start) do
    false
  end

  def valid_identifier?(<<>>, :body) do
    true
  end

  def need_quote?(str, state \\ :start)

  def need_quote?(<<c::utf8, _rest::binary>>, _) when is_utf8_non_identifier_char(c) do
    true
  end

  def need_quote?(
    <<s::utf8, c::utf8, _rest::binary>>,
    :start
  ) when is_utf8_sign_char(s) and is_utf8_digit_char(c) do
    true
  end

  def need_quote?(<<c::utf8, _rest::binary>>, :start) when is_utf8_digit_char(c) do
    true
  end

  def need_quote?(<<_c::utf8, rest::binary>>, _) do
    need_quote?(rest, :body)
  end

  def need_quote?(<<>>, :start) do
    true
  end

  def need_quote?(<<>>, :body) do
    false
  end

  def parse_float_string(bin, state \\ :start, acc \\ [])

  def parse_float_string(<<>>, :start, _acc) do
    {:error, :invalid_float_format}
  end

  def parse_float_string(<<>>, state, acc) when state in [:fraction, :exponent] do
    {:ok, IO.iodata_to_binary(Enum.reverse(acc))}
  end

  def parse_float_string(<<c::utf8, rest::binary>>, :start, acc) when c == ?- or
                                                                      c == ?+  do
    parse_float_string(rest, :start_number, [<<c::utf8>> | acc])
  end

  def parse_float_string(<<c::utf8, rest::binary>>, state, acc) when c in ?0..?9 and state in [:start, :start_number, :body] do
    parse_float_string(rest, :body, [<<c::utf8>> | acc])
  end

  def parse_float_string(<<".", rest::binary>>, :body, acc) do
    parse_float_string(rest, :start_fraction, [<<".">> | acc])
  end

  def parse_float_string(<<"_", rest::binary>>, :body, acc) do
    parse_float_string(rest, :body, acc)
  end

  def parse_float_string(<<"E", rest::binary>>, state, acc) when state in [:body, :fraction] do
    parse_float_string(rest, :start_exponent, [<<"E">> | acc])
  end

  def parse_float_string(<<"e", rest::binary>>, state, acc) when state in [:body, :fraction] do
    parse_float_string(rest, :start_exponent, [<<"E">> | acc])
  end

  def parse_float_string(<<"_", rest::binary>>, :fraction, acc) do
    parse_float_string(rest, :fraction, acc)
  end

  def parse_float_string(<<c::utf8, rest::binary>>, state, acc) when c in ?0..?9 and state in [:fraction, :start_fraction] do
    parse_float_string(rest, :fraction, [<<c::utf8>> | acc])
  end

  def parse_float_string(<<c::utf8, rest::binary>>, :start_exponent, acc) when c == ?- or
                                                                               c == ?+  do
    parse_float_string(rest, :exponent, [<<c::utf8>> | acc])
  end

  def parse_float_string(<<c::utf8, rest::binary>>, state, acc) when c in ?0..?9 and state in [:start_exponent, :exponent] do
    parse_float_string(rest, :exponent, [<<c::utf8>> | acc])
  end

  def parse_float_string(<<"_", rest::binary>>, :exponent, acc) do
    parse_float_string(rest, :exponent, acc)
  end

  def parse_float_string(_, _state, _acc) do
    {:error, :unexpected_characters}
  end
end

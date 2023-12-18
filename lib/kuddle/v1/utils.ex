defmodule Kuddle.V1.Utils do
  import Kuddle.Utils

  @non_identifier_characters [?\\, ?<, ?>, ?{, ?}, ?;, ?[, ?], ?(, ?), ?=, ?,, ?"]

  @doc """
  Check if a string is a valid identifier (that is a plain unbroken character sequence)
  """
  @spec valid_identifier?(String.t()) :: boolean()
  def valid_identifier?(str, state \\ :start)

  def valid_identifier?(<<c::utf8, _rest::binary>>, _) when c in @non_identifier_characters do
    false
  end

  def valid_identifier?(<<c::utf8, _rest::binary>>, _) when c < 0x20 or c > 0x10FFFF do
    false
  end

  def valid_identifier?(
    <<s::utf8, c::utf8, _rest::binary>>,
    :start
  ) when is_utf8_sign_char(s) and is_utf8_digit_char(c) do
    false
  end

  def valid_identifier?(<<c::utf8, _rest::binary>>, :start) when is_utf8_digit_char(c) do
    false
  end

  def valid_identifier?(<<_c::utf8, rest::binary>>, _) do
    valid_identifier?(rest, :body)
  end

  def valid_identifier?(<<>>, :start) do
    true
  end

  def valid_identifier?(<<>>, :body) do
    true
  end

  def need_quote?(str, state \\ :start)

  def need_quote?(<<c::utf8, _rest::binary>>, _) when c in @non_identifier_characters do
    true
  end

  def need_quote?(<<c::utf8, _rest::binary>>, _) when c < 0x20 or c > 0x10FFFF do
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

defmodule Kuddle.Utils do
  @moduledoc """
  Common utility module for kuddle
  """
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

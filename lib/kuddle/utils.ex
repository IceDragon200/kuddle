defmodule Kuddle.Utils do
  @moduledoc """
  Common utility module for kuddle
  """
  import Kuddle.Tokens

  defguard is_utf8_sign(c) when c in [?+, ?-]
  defguard is_utf8_digit(c) when c >= ?0 and c <= ?9
  defguard is_utf8_scalar(c) when (c >= 0x0000 and c <= 0xD7FF) or (c >= 0xE000 and c <= 0x10FFFF)
  defguard is_utf8_direction_control(c) when (c >= 0x2066 and c <= 0x2069) or (c >= 0x202A and c <= 0x202E)

  defmacro add_line(meta, amount \\ 1) do
    quote do
      r_token_meta(unquote(meta),
        line_no: r_token_meta(unquote(meta), :line_no) + unquote(amount),
        col_no: 1
      )
    end
  end

  defmacro add_col(meta, amount \\ 1) do
    quote do
      r_token_meta(unquote(meta),
        col_no: r_token_meta(unquote(meta), :col_no) + unquote(amount)
      )
    end
  end

  @doc """
  Converts a list to a binary, this also handles tokenizer specific escape tuples.
  """
  @spec list_to_utf8_binary(list()) :: binary()
  def list_to_utf8_binary(list) when is_list(list) do
    list
    |> Enum.map(fn
      {:esc, c} when is_integer(c) -> <<c::utf8>>
      {:esc, c} when is_binary(c) -> c
      {:esc, c} when is_list(c) -> list_to_utf8_binary(c)
      c when is_integer(c) -> <<c::utf8>>
      c when is_binary(c) -> c
      c when is_list(c) -> list_to_utf8_binary(c)
    end)
    |> IO.iodata_to_binary()
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

defmodule Kuddle.Utils do
  @moduledoc """
  Common utility module for kuddle
  """
  import Kuddle.Tokens

  defguard is_utf8_bom_char(c) when c == 0xFEFF
  defguard is_utf8_sign_char(c) when c in [?+, ?-]
  defguard is_utf8_digit_char(c) when c >= ?0 and c <= ?9
  defguard is_utf8_scalar_char(c) when (c >= 0x0000 and c <= 0xD7FF) or (c >= 0xE000 and c <= 0x10FFFF)
  defguard is_utf8_direction_control_char(c) when
    (c >= 0x200E and c <= 0x200F) or
    (c >= 0x2066 and c <= 0x2069) or
    (c >= 0x202A and c <= 0x202E)

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

  def utf8_char_byte_size(c) when c < 0x80 do
    1
  end

  def utf8_char_byte_size(c) when c < 0x800 do
    2
  end

  def utf8_char_byte_size(c) when c < 0x10000 do
    3
  end

  def utf8_char_byte_size(c) when c >= 0x10000 do
    4
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

  def trim_leading_and_count(rest, pattern) do
    do_trim_leading_and_count(rest, byte_size(pattern), pattern, 0)
  end

  defp do_trim_leading_and_count(rest, pat_size, pattern, count) do
    case rest do
      <<^pattern::binary-size(pat_size), rest::binary>> ->
        do_trim_leading_and_count(rest, pat_size, pattern, count + 1)

      _ ->
        {rest, count, String.duplicate(pattern, count)}
    end
  end
end

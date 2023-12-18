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
end

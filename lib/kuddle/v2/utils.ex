defmodule Kuddle.V2.Utils do
  import Kuddle.Utils

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

  defguard is_utf8_disallowed_char(c) when not is_utf8_scalar(c) or is_utf8_direction_control(c)

  defguard is_utf8_non_identifier_character(c) when
    is_utf8_space_like_char(c) or
    is_utf8_newline_like_char(c) or
    c < 0x20 or
    is_utf8_disallowed_char(c) or
    c in [
      ?(,
      ?),
      ?{,
      ?},
      ?[,
      ?],
      ?/,
      ?\\,
      ?=,
      ?,,
      ?",
      ?#,
      ?;,
    ]

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

  def split_spaces_and_newlines(<<"\r\n", rest::binary>>, meta, acc) do
    split_spaces_and_newlines(rest, add_line(meta, 1), ["\r\n" | acc])
  end

  def split_spaces_and_newlines(<<c::utf8, rest::binary>>, meta, acc) when is_utf8_newline_like_char(c) do
    split_spaces_and_newlines(rest, add_line(meta, 1), [c | acc])
  end

  def split_spaces_and_newlines(rest, meta, acc) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest, meta}
  end

  @spec split_up_to_newline(binary(), any(), [any()]) :: {binary(), binary(), meta::any()}
  def split_up_to_newline(rest, meta, acc \\ [])

  def split_up_to_newline(<<>> = rest, meta, acc) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest, meta}
  end

  def split_up_to_newline(
    <<"\r\n", rest::binary>> = rest,
    meta,
    acc
  ) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest, add_line(meta)}
  end

  def split_up_to_newline(
    <<c::utf8, rest::binary>> = rest,
    meta,
    acc
  ) when is_utf8_newline_like_char(c) do
    {list_to_utf8_binary(Enum.reverse(acc)), rest, add_line(meta)}
  end

  def split_up_to_newline(
    <<c::utf8, rest::binary>>,
    meta,
    acc
  ) when is_utf8_scalar(c) and not is_utf8_direction_control(c) do
    split_up_to_newline(rest, add_col(meta), [c | acc])
  end

  @doc """
  Check if a string is a valid identifier (that is a plain unbroken character sequence)
  """
  @spec valid_identifier?(String.t()) :: boolean()
  def valid_identifier?(str, state \\ :start)

  def valid_identifier?(<<c::utf8, _rest::binary>>, _) when is_utf8_non_identifier_character(c) do
    false
  end

  def valid_identifier?(<<s::utf8, c::utf8, _rest::binary>>, :start) when is_utf8_sign(s) and is_utf8_digit(c) do
    false
  end

  def valid_identifier?(<<c::utf8, _rest::binary>>, :start) when is_utf8_digit(c) do
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

  def need_quote?(<<c::utf8, _rest::binary>>, _) when is_utf8_non_identifier_character(c) do
    true
  end

  def need_quote?(<<s::utf8, c::utf8, _rest::binary>>, :start) when is_utf8_sign(s) and is_utf8_digit(c) do
    true
  end

  def need_quote?(<<c::utf8, _rest::binary>>, :start) when is_utf8_digit(c) do
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
end

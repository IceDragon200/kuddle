defmodule Kuddle.V1.Utils do
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

  def valid_identifier?(<<"-", c::utf8, _rest::binary>>, :start) when c in ?0..?9 do
    false
  end

  def valid_identifier?(<<c::utf8, _rest::binary>>, :start) when c in ?0..?9 do
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

  def need_quote?(<<c::utf8, _rest::binary>>, :start) when c in ?0..?9 do
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

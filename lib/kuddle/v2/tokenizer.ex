defmodule Kuddle.V2.Tokenizer do
  @moduledoc """
  Intermediate process of converting a KDL1 document into some basic tokens that can be parsed.
  """
  alias Kuddle.Tokens

  import Tokens

  @type token :: Tokens.open_block_token()
               | Tokens.close_block_token()
               | Tokens.slashdash_token()
               | Tokens.comment_token()
               | Tokens.dquote_string_token()
               | Tokens.raw_string_token()
               | Tokens.space_token()
               | Tokens.newline_token()
               | Tokens.equal_token()
               | Tokens.semicolon_token()
               | Tokens.fold_token()
               | Tokens.term_token()

  @type tokens :: [token()]

  defmacrop add_line(meta, amount \\ 1) do
    quote do
      r_token_meta(unquote(meta),
        line_no: r_token_meta(unquote(meta), :line_no) + unquote(amount),
        col_no: 1
      )
    end
  end

  defmacrop add_col(meta, amount \\ 1) do
    quote do
      r_token_meta(unquote(meta),
        col_no: r_token_meta(unquote(meta), :col_no) + unquote(amount)
      )
    end
  end

  @spec tokenize(String.t()) ::
          {:ok, tokens(), rest::String.t()}
          | {:error, term()}
  def tokenize(blob) when is_binary(blob) do
    do_tokenize(blob, :default, nil, [], r_token_meta(line_no: 1, col_no: 1))
  end

  defp do_tokenize(<<>>, :default, nil, doc, _meta) do
    {:ok, Enum.reverse(doc), ""}
  end

  defp do_tokenize(<<"(", rest::binary>>, :default, nil, doc, meta) do
    case String.split(rest, ")", parts: 2) do
      [annotation, rest] ->
        do_tokenize(
          rest,
          :default,
          nil,
          [r_annotation_token(value: annotation) | doc],
          add_col(meta, byte_size(annotation) + 2)
        )

      [_annotation] ->
        {:error, :unexpected_annotation}
    end
  end

  defp do_tokenize(<<"{", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(
      rest,
      :default,
      nil,
      [r_open_block_token(value: 0, meta: meta) | doc],
      add_col(meta)
    )
  end

  defp do_tokenize(<<"}", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(
      rest,
      :default,
      nil,
      [r_close_block_token(value: 0, meta: meta) | doc],
      add_col(meta)
    )
  end

  defp do_tokenize(<<"/-", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(
      rest,
      :default,
      nil,
      [r_slashdash_token(value: 0, meta: meta) | doc],
      add_col(meta, 2)
    )
  end

  defp do_tokenize(<<"/*", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, {:comment, :c_multiline, 0}, [], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"/*", rest::binary>>, {:comment, :c_multiline, depth}, acc, doc, meta) do
    do_tokenize(rest, {:comment, :c_multiline, depth + 1}, ["/*" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"*/", rest::binary>>, {:comment, :c_multiline, 0}, acc, doc, meta) do
    comment = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(
      rest,
      :default,
      nil,
      [r_comment_token(value: {:c_multiline, comment}, meta: meta) | doc],
      add_col(meta, 2)
    )
  end

  defp do_tokenize(<<"*/", rest::binary>>, {:comment, :c_multiline, depth}, acc, doc, meta) do
    do_tokenize(rest, {:comment, :c_multiline, depth - 1}, ["*/" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, {:comment, :c_multiline, _} = s, acc, doc, meta) do
    do_tokenize(rest, s, [<<c::utf8>> | acc], doc, add_col(meta, byte_size(<<c::utf8>>)))
  end

  defp do_tokenize(<<"//", rest::binary>>, :default, nil, doc, meta) do
    {comment, rest} =
      case String.split(rest, "\n", parts: 2) do
        [comment, rest] ->
          {comment, rest}

        [comment] ->
          {comment, ""}
      end

    do_tokenize(
      rest,
      :default,
      nil,
      [r_comment_token(value: {:c, comment}, meta: meta) | doc],
      add_line(meta)
    )
  end

  defp do_tokenize(<<"\"", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :dquote_string, [], doc, add_col(meta))
  end

  # double quote string
  defp do_tokenize(<<"\"", rest::binary>>, :dquote_string, acc, doc, meta) do
    string = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(
      rest,
      :default,
      nil,
      [r_dquote_string_token(value: string, meta: meta) | doc],
      add_col(meta)
    )
  end

  defp do_tokenize(<<"\\u{", rest::binary>>, :dquote_string, acc, doc, meta) do
    [unicode, rest] = String.split(rest, "}", parts: 2)
    meta = add_col(meta, byte_size(unicode) + 4)
    unicode = String.to_integer(unicode, 16)

    do_tokenize(rest, :dquote_string, [<<unicode::utf8>> | acc], doc, meta)
  end

  defp do_tokenize(<<"\\\"", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["\"" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\r", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["\r" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\n", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["\n" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\b", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["\b" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\f", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["\f" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\s", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["\s" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\t", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["\t" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\\\", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["\\" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\/", rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(rest, :dquote_string, ["/" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, :dquote_string, acc, doc, meta) do
    do_tokenize(
      rest,
      :dquote_string,
      [<<c::utf8>> | acc],
      doc,
      add_col(meta, byte_size(<<c::utf8>>))
    )
  end

  defp do_tokenize(<<>>, :dquote_string, acc, _doc, _meta) do
    {:error, {:unterminated_dquote_string, Enum.reverse(acc)}}
  end

  #
  # Raw String
  #
  defp do_tokenize(<<"r\"", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, {:raw_string, "\""}, [], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"r#", rest::binary>>, :default, nil, doc, meta) do
    len = byte_size(rest)
    rest = String.trim_leading(rest, "#")
    hash_count = len - byte_size(rest) + 1
    meta = add_col(meta, 2 + hash_count)
    terminator = "\"" <> String.duplicate("#", hash_count)
    <<"\"", rest::binary>> = rest
    do_tokenize(rest, {:raw_string, terminator}, [], doc, meta)
  end

  defp do_tokenize(<<>>, {:raw_string, _terminator}, acc, _doc, _meta) do
    {:error, {:unterminated_raw_string, Enum.reverse(acc)}}
  end

  defp do_tokenize(
    <<"\"", rest::binary>> = str,
    {:raw_string, terminator} = state,
    acc,
    doc,
    meta
  ) do
    if String.starts_with?(str, terminator) do
      rest = String.trim_leading(str, terminator)
      meta = add_col(meta, byte_size(terminator))
      string = IO.iodata_to_binary(Enum.reverse(acc))
      do_tokenize(rest, :default, nil, [r_raw_string_token(value: string, meta: meta) | doc], meta)
    else
      do_tokenize(rest, state, ["\"" | acc], doc, add_col(meta))
    end
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, {:raw_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [<<c::utf8>> | acc], doc, add_col(meta, byte_size(<<c::utf8>>)))
  end

  defp do_tokenize(<<"\s", rest::binary>>, :default, nil, doc, meta) do
    len = byte_size(rest)
    rest = String.trim_leading(rest, "\s")
    len = len - byte_size(rest) + 1
    do_tokenize(rest, :default, nil, [r_space_token(value: len, meta: meta) | doc], add_col(meta, len))
  end

  defp do_tokenize(<<"\v", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_space_token(value: "\v", meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\t", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_space_token(value: "\t", meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{00A0}", rest::binary>>, :default, nil, doc, meta) do
    # No-Break Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{1680}", rest::binary>>, :default, nil, doc, meta) do
    # Ogham Space Mark
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2000}", rest::binary>>, :default, nil, doc, meta) do
    # En Quad
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2001}", rest::binary>>, :default, nil, doc, meta) do
    # Em Quad
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2002}", rest::binary>>, :default, nil, doc, meta) do
    # En Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2003}", rest::binary>>, :default, nil, doc, meta) do
    # Em Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2004}", rest::binary>>, :default, nil, doc, meta) do
    # Three-Per-Em Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2005}", rest::binary>>, :default, nil, doc, meta) do
    # Four-Per-Em Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2006}", rest::binary>>, :default, nil, doc, meta) do
    # Six-Per-Em Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2007}", rest::binary>>, :default, nil, doc, meta) do
    # Figure Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2008}", rest::binary>>, :default, nil, doc, meta) do
    # Punctuation Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{2009}", rest::binary>>, :default, nil, doc, meta) do
    # Thin Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{200A}", rest::binary>>, :default, nil, doc, meta) do
    # Hair Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{202F}", rest::binary>>, :default, nil, doc, meta) do
    # Narrow No-Break Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{205F}", rest::binary>>, :default, nil, doc, meta) do
    # Medium Mathematical Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\u{3000}", rest::binary>>, :default, nil, doc, meta) do
    # Ideographic Space
    do_tokenize(rest, :default, nil, [r_space_token(value: 1, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\r\n", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_newline_token(value: 1, meta: meta) | doc], add_line(meta))
  end

  defp do_tokenize(<<"\r", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_newline_token(value: 1, meta: meta) | doc], add_line(meta))
  end

  defp do_tokenize(<<"\n", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_newline_token(value: 1, meta: meta) | doc], add_line(meta))
  end

  defp do_tokenize(<<"\f", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_newline_token(value: 1, meta: meta) | doc], add_line(meta))
  end

  defp do_tokenize(<<"\u{2028}", rest::binary>>, :default, nil, doc, meta) do
    # Line Separator
    do_tokenize(rest, :default, nil, [r_newline_token(value: 1, meta: meta) | doc], add_line(meta))
  end

  defp do_tokenize(<<"\u{2029}", rest::binary>>, :default, nil, doc, meta) do
    # Paragraph Separator
    do_tokenize(rest, :default, nil, [r_newline_token(value: 1, meta: meta) | doc], add_line(meta))
  end

  defp do_tokenize(<<"\u{0085}", rest::binary>>, :default, nil, doc, meta) do
    # Next-Line
    do_tokenize(rest, :default, nil, [r_newline_token(value: 1, meta: meta) | doc], add_line(meta))
  end

  defp do_tokenize(<<"=", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_equal_token(value: 0, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<";", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_semicolon_token(value: 0, meta: meta) | doc], add_col(meta))
  end

  defp do_tokenize(<<"\\", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_fold_token(value: 0, meta: meta) | doc], add_col(meta))
  end

  @non_identifier_characters [?=, ?\n, ?\r, ?\s, ?\\, ?<, ?>, ?{, ?}, ?;, ?[, ?], ?(, ?), ?=, ?,, ?"]

  defp do_tokenize(<<c::utf8, _rest::binary>> = rest, :default, nil, doc, _meta)
          when c in @non_identifier_characters or
               c >= 0x10FFFF do
    {:ok, Enum.reverse(doc), rest}
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, {:term, meta}, [<<c::utf8>>], doc, add_col(meta, byte_size(<<c::utf8>>)))
  end

  defp do_tokenize(<<>> = rest, {:term, tmeta}, acc, doc, meta) do
    value = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [r_term_token(value: value, meta: tmeta) | doc], meta)
  end

  defp do_tokenize(<<c::utf8, _rest::binary>> = rest, {:term, tmeta}, acc, doc, meta)
        when c in @non_identifier_characters or
             c >= 0x10FFFF do
    value = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [r_term_token(value: value, meta: tmeta) | doc], meta)
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, {:term, _tmeta} = state, acc, doc, meta) do
    do_tokenize(rest, state, [<<c::utf8>> | acc], doc, add_col(meta, byte_size(<<c::utf8>>)))
  end
end

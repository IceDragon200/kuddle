defmodule Kuddle.Tokenizer do
  @moduledoc """
  Intermediate process of converting a KDL document into some basic tokens that can be parsed.
  """
  @type open_block_token :: {:open_block, unused::integer()}

  @type close_block_token :: {:close_block, unused::integer()}

  @type slashdash_token :: {:slashdash, unused::integer()}

  @type comment_type :: :c | :c_multiline

  @type comment_token :: {:comment, {comment_type(), String.t()}}

  @type dquote_string_token :: {:dquote_string, String.t()}

  @type raw_string_token :: {:raw_string, String.t()}

  @type space_token :: {:space, {String.t(), len::non_neg_integer()}}

  @type newline_token :: {:nl, unused::integer()}

  @type equal_token :: {:=, unused::integer()}

  @type semicolon_token :: {:sc, unused::integer()}

  @type fold_token :: {:fold, unused::integer()}

  @type term_token :: {:term, String.t()}

  @type token :: open_block_token()
               | close_block_token()
               | slashdash_token()
               | comment_token()
               | dquote_string_token()
               | raw_string_token()
               | space_token()
               | newline_token()
               | equal_token()
               | semicolon_token()
               | fold_token()
               | term_token()

  @type tokens :: [token()]

  @spec tokenize(String.t()) ::
          {:ok, tokens(), rest::String.t()}
          | {:error, term()}
  def tokenize(blob) when is_binary(blob) do
    do_tokenize(blob, :default, nil, [])
  end

  defp do_tokenize(<<>>, :default, nil, doc) do
    {:ok, Enum.reverse(doc), ""}
  end

  defp do_tokenize(<<"(", rest::binary>>, :default, nil, doc) do
    case String.split(rest, ")", parts: 2) do
      [annotation, rest] ->
        do_tokenize(rest, :default, nil, [{:annotation, annotation} | doc])

      [_annotation] ->
        {:error, :unexpected_annotation}
    end
  end

  defp do_tokenize(<<"{", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:open_block, 0} | doc])
  end

  defp do_tokenize(<<"}", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:close_block, 0} | doc])
  end

  defp do_tokenize(<<"/-", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:slashdash, 0} | doc])
  end

  defp do_tokenize(<<"/*", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, {:comment, :c_multiline, 0}, [], doc)
  end

  defp do_tokenize(<<"/*", rest::binary>>, {:comment, :c_multiline, depth}, acc, doc) do
    do_tokenize(rest, {:comment, :c_multiline, depth + 1}, ["/*" | acc], doc)
  end

  defp do_tokenize(<<"*/", rest::binary>>, {:comment, :c_multiline, 0}, acc, doc) do
    comment = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [{:comment, {:c_multiline, comment}} | doc])
  end

  defp do_tokenize(<<"*/", rest::binary>>, {:comment, :c_multiline, depth}, acc, doc) do
    do_tokenize(rest, {:comment, :c_multiline, depth - 1}, ["*/" | acc], doc)
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, {:comment, :c_multiline, _} = s, acc, doc) do
    do_tokenize(rest, s, [<<c::utf8>> | acc], doc)
  end

  defp do_tokenize(<<"//", rest::binary>>, :default, nil, doc) do
    {comment, rest} =
      case String.split(rest, "\n", parts: 2) do
        [comment, rest] ->
          {comment, rest}

        [comment] ->
          {comment, ""}
      end

    do_tokenize(rest, :default, nil, [{:comment, {:c, comment}} | doc])
  end

  defp do_tokenize(<<"\"", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :dquote_string, [], doc)
  end

  # double quote string
  defp do_tokenize(<<"\"", rest::binary>>, :dquote_string, acc, doc) do
    string = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [{:dquote_string, string} | doc])
  end

  defp do_tokenize(<<"\\u{", rest::binary>>, :dquote_string, acc, doc) do
    [unicode, rest] = String.split(rest, "}", parts: 2)
    unicode = String.to_integer(unicode, 16)

    do_tokenize(rest, :dquote_string, [<<unicode::utf8>> | acc], doc)
  end

  defp do_tokenize(<<"\\\"", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\"" | acc], doc)
  end

  defp do_tokenize(<<"\\r", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\r" | acc], doc)
  end

  defp do_tokenize(<<"\\n", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\n" | acc], doc)
  end

  defp do_tokenize(<<"\\b", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\b" | acc], doc)
  end

  defp do_tokenize(<<"\\f", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\f" | acc], doc)
  end

  defp do_tokenize(<<"\\s", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\s" | acc], doc)
  end

  defp do_tokenize(<<"\\t", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\t" | acc], doc)
  end

  defp do_tokenize(<<"\\\\", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\\" | acc], doc)
  end

  defp do_tokenize(<<"\\/", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["/" | acc], doc)
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, [<<c::utf8>> | acc], doc)
  end

  defp do_tokenize(<<>>, :dquote_string, acc, _doc) do
    {:error, {:unterminated_dquote_string, Enum.reverse(acc)}}
  end

  # raw string
  defp do_tokenize(<<"r\"", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, {:raw_string, "\""}, [], doc)
  end

  defp do_tokenize(<<"r#", rest::binary>>, :default, nil, doc) do
    len = byte_size(rest)
    rest = String.trim_leading(rest, "#")
    hash_count = len - byte_size(rest) + 1
    terminator = "\"" <> String.duplicate("#", hash_count)
    <<"\"", rest::binary>> = rest
    do_tokenize(rest, {:raw_string, terminator}, [], doc)
  end

  defp do_tokenize(<<>>, {:raw_string, _terminator}, acc, _doc) do
    {:error, {:unterminated_raw_string, Enum.reverse(acc)}}
  end

  defp do_tokenize(<<"\"", rest::binary>> = str, {:raw_string, terminator} = state, acc, doc) do
    if String.starts_with?(str, terminator) do
      rest = String.trim_leading(str, terminator)
      string = IO.iodata_to_binary(Enum.reverse(acc))
      do_tokenize(rest, :default, nil, [{:raw_string, string} | doc])
    else
      do_tokenize(rest, state, ["\"" | acc], doc)
    end
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, {:raw_string, _} = state, acc, doc) do
    do_tokenize(rest, state, [<<c::utf8>> | acc], doc)
  end

  defp do_tokenize(<<"\s", rest::binary>>, :default, nil, doc) do
    len = byte_size(rest)
    rest = String.trim_leading(rest, "\s")
    len = len - byte_size(rest) + 1
    do_tokenize(rest, :default, nil, [{:space, len} | doc])
  end

  defp do_tokenize(<<"\t", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:space, "\t"} | doc])
  end

  defp do_tokenize(<<"\u{00A0}", rest::binary>>, :default, nil, doc) do
    # No-Break Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{1680}", rest::binary>>, :default, nil, doc) do
    # Ogham Space Mark
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2000}", rest::binary>>, :default, nil, doc) do
    # En Quad
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2001}", rest::binary>>, :default, nil, doc) do
    # Em Quad
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2002}", rest::binary>>, :default, nil, doc) do
    # En Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2003}", rest::binary>>, :default, nil, doc) do
    # Em Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2004}", rest::binary>>, :default, nil, doc) do
    # Three-Per-Em Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2005}", rest::binary>>, :default, nil, doc) do
    # Four-Per-Em Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2006}", rest::binary>>, :default, nil, doc) do
    # Six-Per-Em Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2007}", rest::binary>>, :default, nil, doc) do
    # Figure Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2008}", rest::binary>>, :default, nil, doc) do
    # Punctuation Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{2009}", rest::binary>>, :default, nil, doc) do
    # Thin Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{200A}", rest::binary>>, :default, nil, doc) do
    # Hair Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{202F}", rest::binary>>, :default, nil, doc) do
    # Narrow No-Break Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{205F}", rest::binary>>, :default, nil, doc) do
    # Medium Mathematical Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\u{3000}", rest::binary>>, :default, nil, doc) do
    # Ideographic Space
    do_tokenize(rest, :default, nil, [{:space, 1} | doc])
  end

  defp do_tokenize(<<"\r\n", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:nl, 1} | doc])
  end

  defp do_tokenize(<<"\r", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:nl, 1} | doc])
  end

  defp do_tokenize(<<"\n", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:nl, 1} | doc])
  end

  defp do_tokenize(<<"\f", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:nl, 1} | doc])
  end

  defp do_tokenize(<<"\u{2028}", rest::binary>>, :default, nil, doc) do
    # Line Separator
    do_tokenize(rest, :default, nil, [{:nl, 1} | doc])
  end

  defp do_tokenize(<<"\u{2029}", rest::binary>>, :default, nil, doc) do
    # Paragraph Separator
    do_tokenize(rest, :default, nil, [{:nl, 1} | doc])
  end

  defp do_tokenize(<<"\u{0085}", rest::binary>>, :default, nil, doc) do
    # Next-Line
    do_tokenize(rest, :default, nil, [{:nl, 1} | doc])
  end

  defp do_tokenize(<<"=", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:=, 0} | doc])
  end

  defp do_tokenize(<<";", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:sc, 0} | doc])
  end

  defp do_tokenize(<<"\\", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:fold, 0} | doc])
  end

  @non_identifier_characters [?=, ?\n, ?\r, ?\s, ?\\, ?<, ?>, ?{, ?}, ?;, ?[, ?], ?(, ?), ?=, ?,, ?"]

  defp do_tokenize(<<c::utf8, _rest::binary>> = rest, :default, nil, doc)
          when c in @non_identifier_characters or
               c >= 0x10FFFF do
    {:ok, Enum.reverse(doc), rest}
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :term, [<<c::utf8>>], doc)
  end

  defp do_tokenize(<<>> = rest, :term, acc, doc) do
    value = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [{:term, value} | doc])
  end

  defp do_tokenize(<<c::utf8, _rest::binary>> = rest, :term, acc, doc)
        when c in @non_identifier_characters or
             c >= 0x10FFFF do
    value = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [{:term, value} | doc])
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, :term, acc, doc) do
    do_tokenize(rest, :term, [<<c::utf8>> | acc], doc)
  end
end

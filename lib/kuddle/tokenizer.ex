defmodule Kuddle.Tokenizer do
  def tokenize(blob) when is_binary(blob) do
    do_tokenize(blob, :default, nil, [])
  end

  defp do_tokenize(<<>>, :default, nil, doc) do
    {:ok, Enum.reverse(doc)}
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
    [comment, rest] = String.split(rest, "\n", parts: 2)
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

  defp do_tokenize(<<"\\r", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\r" | acc], doc)
  end

  defp do_tokenize(<<"\\n", rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, ["\n" | acc], doc)
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

  defp do_tokenize(<<c::utf8, rest::binary>>, :dquote_string, acc, doc) do
    do_tokenize(rest, :dquote_string, [<<c::utf8>> | acc], doc)
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
    do_tokenize(rest, :default, nil, [{:space, {"\s", len}} | doc])
  end

  defp do_tokenize(<<"\t", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:space, {"\t", 1}} | doc])
  end

  defp do_tokenize(<<"\n", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:nl, 1} | doc])
  end

  defp do_tokenize(<<"\r\n", rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :default, nil, [{:crnl, 1} | doc])
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

  defp do_tokenize(<<c::utf8, rest::binary>>, :default, nil, doc) do
    do_tokenize(rest, :term, [<<c::utf8>>], doc)
  end

  defp do_tokenize(<<>> = rest, :term, acc, doc) do
    value = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [{:term, value} | doc])
  end

  defp do_tokenize(<<c, _rest::binary>> = rest, :term, acc, doc) when c == ?= or
                                                              c == ?\n or
                                                              c == ?\r or
                                                              c == ?\s or
                                                              c == ?; or
                                                              c == ?- do
    value = IO.iodata_to_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [{:term, value} | doc])
  end

  defp do_tokenize(<<c::utf8, rest::binary>>, :term, acc, doc) do
    do_tokenize(rest, :term, [<<c::utf8>> | acc], doc)
  end
end

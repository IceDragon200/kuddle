defmodule Kuddle.V2.Tokenizer do
  @moduledoc """
  Intermediate process of converting a KDL2 document into some basic tokens that can be parsed.
  """
  alias Kuddle.Tokens

  import Tokens
  import Kuddle.Utils
  import Kuddle.V2.Utils

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

  @spec tokenize(String.t()) ::
          {:ok, tokens(), rest::String.t()}
          | {:error, term()}
  def tokenize(blob) when is_binary(blob) do
    do_tokenize(blob, :start, nil, [], r_token_meta(line_no: 1, col_no: 1))
  end

  defp do_tokenize(<<0xFEFF::utf8, rest::binary>>, :start, nil, doc, meta) do
    # BOM, if you're reading from file, you should use trim_bom really
    do_tokenize(rest, :default, nil, doc, add_col(meta, 2))
  end

  defp do_tokenize(rest, :start, nil, doc, meta) do
    # if no BOM is present, just switch to default state and continue tokenizing
    do_tokenize(rest, :default, nil, doc, add_col(meta, 2))
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

  #
  # Multiline Comments
  #
  defp do_tokenize(<<"/*", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, {:comment, :c_multiline, 0}, [], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"/*", rest::binary>>, {:comment, :c_multiline, depth}, acc, doc, meta) do
    do_tokenize(rest, {:comment, :c_multiline, depth + 1}, ["/*" | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"*/", rest::binary>>, {:comment, :c_multiline, 0}, acc, doc, meta) do
    comment = list_to_utf8_binary(Enum.reverse(acc))
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
    do_tokenize(rest, s, [c | acc], doc, add_col(meta, byte_size(<<c::utf8>>)))
  end

  #
  # Single line comment
  #
  defp do_tokenize(<<"//", rest::binary>>, :default, nil, doc, meta) do
    meta = add_col(meta, 2)
    {comment, rest, meta} = split_up_to_newline(rest, meta)

    do_tokenize(
      rest,
      :default,
      nil,
      [r_comment_token(value: {:c, comment}, meta: meta) | doc],
      meta
    )
  end

  #
  # Double-Quoted String
  #
  defp do_tokenize(
    <<"\"", "\r\n", rest::binary>>,
    :default,
    nil,
    doc,
    meta
  ) do
    do_tokenize(rest, {:dquote_string, :ml}, [], doc, add_col(meta))
  end

  defp do_tokenize(
    <<"\"", c::utf8, rest::binary>>,
    :default,
    nil,
    doc,
    meta
  ) when is_utf8_newline_like_char(c) do
    do_tokenize(rest, {:dquote_string, :ml}, [], doc, add_col(meta))
  end

  defp do_tokenize(<<"\"", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, {:dquote_string, :s}, [], doc, add_col(meta))
  end

  defp do_tokenize(<<>>, {:dquote_string, _}, acc, _doc, _meta) do
    {:error, {:unterminated_dquote_string, list_to_utf8_binary(Enum.reverse(acc))}}
  end

  defp do_tokenize(<<"\"", rest::binary>>, {:dquote_string, :s} = _state, acc, doc, meta) do
    string = list_to_utf8_binary(Enum.reverse(acc))
    do_tokenize(
      rest,
      :default,
      nil,
      [r_dquote_string_token(value: string, meta: meta) | doc],
      add_col(meta)
    )
  end

  defp do_tokenize(<<"\"", rest::binary>>, {:dquote_string, :ml} = _state, acc, doc, meta) do
    string = list_to_utf8_binary(Enum.reverse(acc))
    do_tokenize(
      rest,
      :default,
      nil,
      [r_dquote_string_token(value: string, meta: meta) | doc],
      add_col(meta)
    )
  end

  defp do_tokenize(<<"\\\"", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [{:esc, "\""} | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\r", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [{:esc, "\r"} | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\n", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [{:esc, "\n"} | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\b", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [{:esc, "\b"} | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\f", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [{:esc, "\f"} | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\s", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [{:esc, "\s"} | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(
    <<"\\", c::utf8, _rest::binary>> = rest,
    {:dquote_string, _} = state,
    acc,
    doc,
    meta
  ) when is_utf8_space_like_char(c) or is_utf8_newline_like_char(c) do
    <<"\\", rest::binary>> = rest
    {spaces, rest, meta} = split_spaces_and_newlines(rest, meta)
    do_tokenize(rest, state, acc, doc, add_col(meta, byte_size(spaces)))
  end

  defp do_tokenize(<<"\\t", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [{:esc, "\t"} | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\\\", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, [{:esc, "\\"} | acc], doc, add_col(meta, 2))
  end

  defp do_tokenize(<<"\\u{", rest::binary>>, {:dquote_string, _} = state, acc, doc, meta) do
    # Unicode sequence
    meta = add_col(meta, 3)
    case parse_unicode_sequence(rest, meta) do
      {:ok, {c, rest, meta}} ->
        do_tokenize(rest, state, [{:esc, c} | acc], doc, meta)

      {:error, _} = err ->
        err
    end
  end

  defp do_tokenize(
    <<c::utf8, rest::binary>>,
    {:dquote_string, _} = state,
    acc,
    doc,
    meta
  ) when is_utf8_space_like_char(c) do
    do_tokenize(
      rest,
      state,
      [c | acc],
      doc,
      add_col(meta, byte_size(<<c::utf8>>))
    )
  end

  defp do_tokenize(
    <<"\r\n", rest::binary>>,
    {:dquote_string, _} = state,
    acc,
    doc,
    meta
  ) do
    do_tokenize(
      rest,
      state,
      ["\r\n" | acc],
      doc,
      add_line(meta, 1)
    )
  end

  defp do_tokenize(
    <<c::utf8, rest::binary>>,
    {:dquote_string, _} = state,
    acc,
    doc,
    meta
  ) when is_utf8_newline_like_char(c) do
    do_tokenize(
      rest,
      state,
      [c | acc],
      doc,
      add_line(meta, 1)
    )
  end

  defp do_tokenize(
    <<"\"", _rest::binary>> = rest,
    {:dquote_string, _},
    _acc,
    _doc,
    _meta
  ) do
    {:error, {:raw_backslash_in_string, rest}}
  end

  defp do_tokenize(
    <<c::utf8, rest::binary>>,
    {:dquote_string, _} = state,
    acc,
    doc,
    meta
  ) when c > 0x20 and is_utf8_scalar(c) and not is_utf8_disallowed_char(c) do
    do_tokenize(
      rest,
      state,
      [c | acc],
      doc,
      add_col(meta, byte_size(<<c::utf8>>))
    )
  end

  #
  # Raw String & Keyword handling
  #
  defp do_tokenize(<<"#", rest::binary>>, :default, nil, doc, org_meta) do
    len = byte_size(rest)
    meta = add_col(org_meta, 1)
    case rest do
      <<"#", _rest::binary>> ->
        rest = String.trim_leading(rest, "#")
        hash_count = len - byte_size(rest) + 1
        # `"` + `#`(N)
        meta = add_col(meta, 1 + hash_count)
        terminator = "\"" <> String.duplicate("#", hash_count)
        <<"\"", rest::binary>> = rest
        do_tokenize(rest, {:raw_string, terminator}, [], doc, meta)

      <<"\"", rest::binary>> ->
        meta = add_col(meta, 1)
        terminator = "\"#"
        do_tokenize(rest, {:raw_string, terminator}, [], doc, meta)

      _ ->
        # special case for handling keywords
        do_tokenize(rest, {:term, org_meta}, ["#"], doc, org_meta)
    end
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
      string = list_to_utf8_binary(Enum.reverse(acc))
      do_tokenize(rest, :default, nil, [r_raw_string_token(value: string, meta: meta) | doc], meta)
    else
      do_tokenize(rest, state, ["\"" | acc], doc, add_col(meta))
    end
  end

  # 0x0D,0x0A - special sequence
  defp do_tokenize(<<"\r\n", rest::binary>>, {:raw_string, _} = state, acc, doc, meta) do
    do_tokenize(rest, state, ["\r\n" | acc], doc, add_line(meta))
  end

  # spaces
  defp do_tokenize(
    <<c::utf8, _rest::binary>> = rest,
    {:raw_string, _} = state,
    acc,
    doc,
    meta
  ) when is_utf8_space_like_char(c) do
    {spaces, rest} = split_spaces(rest)
    do_tokenize(rest, state, [spaces | acc], doc, add_col(meta, byte_size(spaces)))
  end

  # newlines
  defp do_tokenize(
    <<c::utf8, rest::binary>>,
    {:raw_string, _} = state,
    acc,
    doc,
    meta
  ) when is_utf8_newline_like_char(c) do
    do_tokenize(rest, state, [<<c::utf8>> | acc], doc, add_col(meta, byte_size(<<c::utf8>>)))
  end

  defp do_tokenize(
    <<c::utf8, _rest::binary>> = rest,
    {:raw_string, _} = _state,
    _acc,
    _doc,
    _meta
  ) when c < 0x20 or c == 0x7F or is_utf8_direction_control(c) or not is_utf8_scalar(c) do
    {:error, {:invalid_raw_string_body, rest}}
  end

  defp do_tokenize(
    <<c::utf8, rest::binary>>,
    {:raw_string, _} = state,
    acc,
    doc,
    meta
  ) when is_utf8_scalar(c) do
    do_tokenize(
      rest,
      state,
      [<<c::utf8>> | acc],
      doc,
      add_col(meta, byte_size(<<c::utf8>>))
    )
  end

  #
  # Space, newline and misc tokens
  #

  # 0x0D,0x0A - special sequence
  defp do_tokenize(<<"\r\n", rest::binary>>, :default, nil, doc, meta) do
    do_tokenize(rest, :default, nil, [r_newline_token(value: 1, meta: meta) | doc], add_line(meta))
  end

  # Spaces
  defp do_tokenize(
    <<c::utf8, _rest::binary>> = rest,
    :default,
    nil,
    doc,
    meta
  ) when is_utf8_space_like_char(c) do
    {spaces, rest} = split_spaces(rest)
    do_tokenize(
      rest,
      :default,
      nil,
      [r_space_token(value: spaces, meta: meta) | doc],
      add_col(meta, byte_size(spaces))
    )
  end

  # Newlines
  defp do_tokenize(
    <<c::utf8, rest::binary>>,
    :default,
    nil,
    doc,
    meta
  ) when is_utf8_newline_like_char(c) do
    do_tokenize(
      rest,
      :default,
      nil,
      [r_newline_token(value: <<c::utf8>>, meta: meta) | doc],
      add_line(meta)
    )
  end

  # Catch all for all other sub 0x20 characters
  defp do_tokenize(
    <<c::utf8, _rest::binary>> = rest,
    :default,
    nil,
    _doc,
    meta
  ) when c < 0x20 or c == 0x7F or is_utf8_direction_control(c) do
    # ABORT
    {:error, {:bad_tokenize, rest, meta}}
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

  defp do_tokenize(
    <<c::utf8, _rest::binary>> = rest,
    :default,
    nil,
    doc,
    _meta
  ) when is_utf8_non_identifier_character(c) do
    {:ok, Enum.reverse(doc), rest}
  end

  #
  # Identifiers / Terms
  #
  defp do_tokenize(
    <<c::utf8, rest::binary>>,
    :default,
    nil,
    doc,
    meta
  ) when is_utf8_scalar(c) and not is_utf8_non_identifier_character(c) do
    do_tokenize(rest, {:term, meta}, [<<c::utf8>>], doc, add_col(meta, byte_size(<<c::utf8>>)))
  end

  defp do_tokenize(
    <<>> = rest,
    {:term, tmeta},
    acc,
    doc,
    meta
  ) do
    value = list_to_utf8_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [r_term_token(value: value, meta: tmeta) | doc], meta)
  end

  defp do_tokenize(
    <<c::utf8, _rest::binary>> = rest,
    {:term, _tmeta},
    acc,
    _doc,
    _meta
  ) when c == ?# do
    {:error, {:invalid_identifier, list_to_utf8_binary([Enum.reverse(acc), rest])}}
  end

  defp do_tokenize(
    <<c::utf8, _rest::binary>> = rest,
    {:term, tmeta},
    acc,
    doc,
    meta
  ) when is_utf8_non_identifier_character(c) do
    value = list_to_utf8_binary(Enum.reverse(acc))
    do_tokenize(rest, :default, nil, [r_term_token(value: value, meta: tmeta) | doc], meta)
  end

  defp do_tokenize(
    <<c::utf8, rest::binary>>,
    {:term, _tmeta} = state,
    acc,
    doc,
    meta
  ) when is_utf8_scalar(c) do
    do_tokenize(rest, state, [c | acc], doc, add_col(meta, byte_size(<<c::utf8>>)))
  end

  defp parse_unicode_sequence(rest, meta, acc \\ [])

  defp parse_unicode_sequence(<<>>, _meta, _acc) do
    {:error, :premature_termination}
  end

  defp parse_unicode_sequence(
    <<c::utf8, rest::binary>>,
    meta,
    acc
  ) when (c >= ?0 and c <= ?9) or (c >= ?A and c <= ?F) or (c >= ?a and c <= ?f) do
    parse_unicode_sequence(rest, add_col(meta), [c | acc])
  end

  defp parse_unicode_sequence(
    <<"}", rest::binary>>,
    meta,
    acc
  ) do
    # the accumulator is a valid charlist at the moment so we can quickly turn it into a b
    c = List.to_integer(Enum.reverse(acc), 16)
    {:ok, {c, rest, meta}}
  end

  defp parse_unicode_sequence(_rest, _meta, _acc) do
    {:error, :unexpected_character}
  end
end

defmodule Kuddle.Tokens do
  @moduledoc """
  Tokens emitted by the Tokenizers.
  """
  import Record

  @type token_meta :: {:token_meta, line_no::integer(), col_no::integer()}

  @type open_annotation_token :: {:open_annotation, unused::any(), token_meta()}

  @type close_annotation_token :: {:close_annotation, unused::any(), token_meta()}

  @type open_block_token :: {:open_block, unused::any(), token_meta()}

  @type close_block_token :: {:close_block, unused::any(), token_meta()}

  @type slashdash_token :: {:slashdash, unused::any(), token_meta()}

  @type comment_type :: :line | :span | :multiline

  @type comment_token :: {:comment, {comment_type(), String.t()}, token_meta()}

  @type dquote_string_token :: {:dquote_string, String.t(), token_meta()}

  @type raw_string_token :: {:raw_string, String.t(), token_meta()}

  @type space_token :: {:space, {String.t(), len::non_neg_integer()}, token_meta()}

  @type newline_token :: {:nl, unused::any(), token_meta()}

  @type equal_token :: {:=, unused::any(), token_meta()}

  @type semicolon_token :: {:sc, unused::any(), token_meta()}

  @type fold_token :: {:fold, unused::any(), token_meta()}

  @type term_token :: {:term, String.t(), token_meta()}

  defrecord :r_token_meta, :meta, [line_no: 1, col_no: 1]

  # v1 Token - V1 uses asingle annotation token type, v2 uses this after extracting the tokens
  # in the parsing step
  defrecord :r_annotation_token, :annotation, [:value, :meta]

  # v2 Tokens - V2 marks the brackets and expects the decoder to handle whatever is between them
  defrecord :r_open_annotation_token, :open_annotation, [:value, :meta]
  defrecord :r_close_annotation_token, :close_annotation, [:value, :meta]

  defrecord :r_open_block_token, :open_block, [:value, :meta]

  defrecord :r_close_block_token, :close_block, [:value, :meta]

  defrecord :r_slashdash_token, :slashdash, [:value, :meta]

  defrecord :r_comment_token, :comment, [:value, :meta]

  defrecord :r_dquote_string_token, :dquote_string, [:value, :meta]

  defrecord :r_raw_string_token, :raw_string, [:value, :meta]

  defrecord :r_space_token, :space, [:value, :meta]

  defrecord :r_newline_token, :nl, [:value, :meta]

  defrecord :r_equal_token, :=, [:value, :meta]

  defrecord :r_semicolon_token, :sc, [:value, :meta]

  defrecord :r_fold_token, :fold, [:value, :meta]

  defrecord :r_term_token, :term, [:value, :meta]
end

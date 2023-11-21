defmodule Kuddle.Tokens do
  import Record

  defrecord :r_token_meta, :meta, [line_no: 1, col_no: 1]

  defrecord :r_annotation_token, :annotation, [:value, :meta]

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

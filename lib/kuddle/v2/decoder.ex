defmodule Kuddle.V2.Decoder do
  @moduledoc """
  Tokenizes and parses KDL2 documents into kuddle documents.
  """
  alias Kuddle.Value
  alias Kuddle.Node

  import Kuddle.Tokens
  import Kuddle.V2.Utils
  import Kuddle.V2.Tokenizer

  import Record

  @typedoc """
  Parsed tokens from the Tokenizer, these will be processed and converted into the final nodes for
  the document.
  """
  @type tokens :: Kuddle.V2.Tokenizer.tokens()

  @typedoc """
  A single node in the Kuddle document
  """
  @type document_node :: Node.t()

  @typedoc """
  A kuddle document is a list of Kuddle Nodes
  """
  @type document :: [document_node()]

  defrecord :node_state, :node,
    depth: 0,
    spaces: 0,
    state: :attributes

  defrecord :default_state, :default,
    depth: 0

  @doc """
  Same as decode/1, but will raise a Kuddle.DecodeError on error from decode.
  """
  @spec decode!(String.t()) :: document()
  def decode!(blob) when is_binary(blob) do
    case decode(blob) do
      {:ok, tokens, _rest} ->
        tokens

      {:error, reason} ->
        raise Kuddle.DecodeError, reason: reason
    end
  end

  @doc """
  Tokenize and parse a given KDL document.

  If successful, it will return `{:ok, document, tokens}`, where document is the list of nodes that
  were parsed and tokens are any unparsed tokens.
  """
  @spec decode(String.t()) ::
    {:ok, document(), tokens()}
    | {:error, term()}
  def decode(blob) when is_binary(blob) do
    case tokenize(blob) do
      {:ok, tokens, ""} ->
        decode(tokens)

      {:ok, _tokens, rest} ->
        {:error, {:incomplete_tokenize, rest}}

      {:error, _} = err ->
        err
    end
  end

  def decode(tokens) when is_list(tokens) do
    parse(tokens, default_state(depth: 0), [], [])
  end

  defp parse([], default_state(depth: 0), [], doc) do
    handle_parse_exit([], doc)
  end

  defp parse(
    [r_open_annotation_token(meta: meta) | tokens],
    default_state(depth: depth) = state,
    acc,
    doc
  ) do
    case parse(tokens, {:annotation, depth}, [], []) do
      {:ok, [], _tokens} ->
        res = [state: state, reason: :empty, document: doc]
        {:error, {:invalid_annotation, res}}

      {:ok, [token], tokens} ->
        case token_to_value(token) do
          {:ok, %Value{value: value}} ->
            parse(tokens, state, [r_annotation_token(value: value, meta: meta) | acc], doc)

          {:error, reason} ->
            res = [state: state, reason: reason, document: doc]
            {:error, {:invalid_annotation, res}}
        end

      {:ok, tokens, _} ->
        res = [state: state, reason: {:unexpected_tokens, tokens}, document: doc]
        {:error, {:invalid_annotation, res}}

      {:error, reason} ->
        res = [state: state, reason: reason, document: doc]
        {:error, {:invalid_annotation, res}}
    end
  end

  defp parse(
    [r_slashdash_token() = token | _tokens],
    default_state() = state,
    [r_annotation_token() | _],
    doc
  ) do
    # this handles this specific case:
    # ANNOTATION SLASHDASH NODE-NAME
    # (type)/-node
    res = [token: token, state: state, document: doc]
    {:error, {:unexpected_slashdash_origin, res}}
  end

  defp parse([r_slashdash_token() | tokens], default_state() = state, acc, doc) do
    # add the slashdash to the document accumulator
    # when the next parse is done, the slashdash will cause the next
    # component item in the accumulator to be dropped
    parse(tokens, state, acc, [:slashdash | doc])
  end

  defp parse([r_comment_token() | tokens], default_state() = state, acc, doc) do
    parse(tokens, state, acc, doc)
  end

  defp parse([r_fold_token() = token], default_state() = state, _acc, doc) do
    res = [token: token, state: state, document: doc]
    {:error, {:unexpected_end_of_document, res}}
  end

  defp parse([r_fold_token() | tokens], default_state() = state, acc, doc) do
    case unfold_leading_tokens(tokens) do
      {:ok, _, tokens} ->
        parse(tokens, state, acc, doc)

      {:error, _} = err ->
        err
    end
  end

  defp parse([r_semicolon_token() | tokens], default_state() = state, acc, doc) do
    # loose semi-colon
    parse(tokens, state, acc, doc)
  end

  defp parse([r_newline_token() | tokens], default_state() = state, acc, doc) do
    # trim leading newlines
    parse(tokens, state, acc, doc)
  end

  defp parse([r_space_token() | tokens], default_state() = state, acc, doc) do
    # trim leading space
    parse(tokens, state, acc, doc)
  end

  defp parse(
    [r_term_token(value: name) = token | tokens],
    default_state(depth: depth) = state,
    acc,
    doc
  ) do
    # node
    if valid_identifier?(name) do
      annotations = extract_annotations(acc)
      parse(tokens, node_state(depth: depth, spaces: 0), {name, annotations, []}, doc)
    else
      res = [state: state, reason: :invalid_identifier, document: doc, token: token]
      {:error, {:invalid_identifier, res}}
    end
  end

  defp parse(
    [r_dquote_string_token(value: name) | tokens],
    default_state(depth: depth),
    acc,
    doc
  ) do
    # double quote initiated node
    annotations = extract_annotations(acc)
    parse(tokens, node_state(depth: depth, spaces: 0), {name, annotations, []}, doc)
  end

  defp parse([r_raw_string_token(value: name) | tokens], default_state(depth: depth), acc, doc) do
    # raw string node
    annotations = extract_annotations(acc)
    parse(tokens, node_state(depth: depth, spaces: 0), {name, annotations, []}, doc)
  end

  #
  # Raw Block - this will be treated as an error if it remains in the document after being pruned
  #
  defp parse(
    [r_open_block_token() | tokens],
    default_state(depth: depth) = state,
    acc,
    doc
  ) do
    case parse(tokens, default_state(depth: depth + 1), [], []) do
      {:ok, children, tokens} ->
        case trim_leading_space(tokens) do
          {_, [r_close_block_token() | tokens]} ->
            parse(tokens, state, acc, [{:raw_block, children} | doc])
        end

      {:error, _} = err ->
        err
    end
  end

  #
  # Annotation
  #
  defp parse([], {:annotation, _depth} = state, [], doc) do
    res = [state: state, reason: :no_tokens_remaining, document: doc]
    {:error, {:invalid_annotation_parse_state, res}}
  end

  defp parse([r_space_token() | tokens], {:annotation, _depth} = state, acc, doc) do
    # trim spaces
    parse(tokens, state, acc, doc)
  end

  defp parse([r_comment_token() | tokens], {:annotation, _depth} = state, acc, doc) do
    parse(tokens, state, acc, doc)
  end

  defp parse([r_term_token() = token | tokens], {:annotation, _depth} = state, [] = acc, doc) do
    parse(tokens, state, acc, [token | doc])
  end

  defp parse([r_dquote_string_token() = token | tokens], {:annotation, _depth} = state, [] = acc, doc) do
    parse(tokens, state, acc, [token | doc])
  end

  defp parse([r_close_annotation_token() | tokens], {:annotation, _depth}, [], doc) do
    handle_parse_exit(tokens, doc)
  end

  defp parse(tokens, {:annotation, _depth} = state, [], doc) do
    res = [state: state, reason: {:unexpected_tokens, tokens}, document: doc]
    {:error, {:invalid_annotation_parse_state, res}}
  end

  #
  # Node
  #
  defp parse(
    [r_slashdash_token() | tokens],
    node_state(depth: _depth, spaces: _node_spaces) = state,
    {name, annotations, attrs},
    doc
  ) do
    # slashdash needs to behave like an unfold where it consumes as many spaces as it can
    case trim_leading_space_for_slashdash(tokens) do
      {:ok, {_, tokens}} ->
        parse(
          tokens,
          state,
          {name, annotations, [:slashdash | attrs]},
          doc
        )

      {:error, _reason} = err ->
        # handles cases where the slashdash consumes every tailing token and has no content left
        err
    end
  end

  defp parse([r_comment_token() | tokens], node_state() = state, acc, doc) do
    # trim comments
    parse(tokens, state, acc, doc)
  end

  defp parse([r_space_token() | tokens], node_state(spaces: spaces) = state, acc, doc) do
    # collect leading spaces in node
    parse(tokens, node_state(state, spaces: spaces + 1), acc, doc)
  end

  defp parse([r_fold_token() | tokens], node_state(spaces: node_spaces) = state, acc, doc) do
    case unfold_leading_tokens(tokens) do
      {:ok, fold_spaces, tokens} ->
        parse(tokens, node_state(state, spaces: node_spaces + fold_spaces), acc, doc)

      {:error, _} = err ->
        err
    end
  end

  defp parse(
    [{token_type, _value, _meta} | tokens],
    node_state(depth: depth) = state,
    {name, node_annotations, attrs},
    doc
  ) when token_type in [:nl, :sc] do
    case resolve_node_attributes(attrs) do
      {:ok, attrs} ->
        node = %Node{
          name: name,
          annotations: node_annotations,
          attributes: attrs,
          children: nil,
        }
        parse(tokens, default_state(depth: depth), [], [node | doc])

      {:error, reason} ->
        res = [state: state, reason: reason, document: doc]
        {:error, {:invalid_node_attributes, res}}
    end
  end

  defp parse(
    [r_close_block_token() | _tokens] = tokens,
    node_state(depth: depth) = state,
    {name, node_annotations, attrs},
    doc
  ) do
    case resolve_node_attributes(attrs) do
      {:ok, attrs} ->
        node = %Node{
          name: name,
          annotations: node_annotations,
          attributes: attrs,
          children: nil,
        }
        parse(tokens, default_state(depth: depth), [], [node | doc])

      {:error, reason} ->
        res = [state: state, reason: reason, document: doc]
        {:error, {:invalid_node_attributes, res}}
    end
  end

  defp parse(
    [token | _tokens],
    node_state(spaces: 0) = state,
    {_name, _node_annotations, _attrs},
    doc
  ) do
    res = [state: state, reason: :missing_space, document: doc, token: token]
    {:error, {:unexpected_token_after_node_name, res}}
  end

  defp parse(
    [r_open_block_token() | tokens],
    node_state(depth: depth, spaces: spaces) = state,
    {name, node_annotations, attrs},
    doc
  ) when spaces > 0 do
    state = node_state(state, state: :children)
    case parse(tokens, default_state(depth: depth + 1), [], []) do
      {:ok, children, tokens} ->
        case trim_leading_space(tokens) do
          {_, [r_close_block_token() | tokens]} ->
            case attrs do
              [:slashdash | attrs] ->
                # discard the children, and remain in the parsing state as if we never saw an
                # open block
                parse(tokens, state, {name, node_annotations, attrs}, doc)

              attrs when is_list(attrs) ->
                case resolve_node_attributes(attrs) do
                  {:ok, attrs} ->
                    node = %Node{
                      name: name,
                      annotations: node_annotations,
                      attributes: attrs,
                      children: children,
                    }
                    parse(tokens, default_state(depth: depth), [], [node | doc])

                  {:error, reason} ->
                    res = [state: state, reason: reason, document: doc]
                    {:error, {:invalid_node_attributes, res}}
                end
            end
        end

      {:error, _} = err ->
        err
    end
  end

  defp parse(
    [r_open_annotation_token(meta: meta) | tokens],
    node_state(depth: depth, spaces: spaces, state: :attributes) = state,
    {name, node_annotations, attrs},
    doc
  ) when spaces > 0 do
    case parse(tokens, {:annotation, depth}, [], []) do
      {:ok, [], _tokens} ->
        res = [state: state, reason: :empty, document: doc]
        {:error, {:invalid_annotation, res}}

      {:ok, [token], tokens} ->
        case token_to_value(token) do
          {:ok, %Value{value: value}} ->
            attrs = [r_annotation_token(value: value, meta: meta) | attrs]
            parse(tokens, state, {name, node_annotations, attrs}, doc)

          {:error, reason} ->
            res = [state: state, reason: reason, document: doc]
            {:error, {:invalid_annotation, res}}
        end

      {:ok, tokens, _} ->
        res = [state: state, reason: {:unexpected_tokens, tokens}, document: doc]
        {:error, {:invalid_annotation, res}}

      {:error, reason} ->
        res = [state: state, reason: reason, document: doc]
        {:error, {:invalid_annotation, res}}
    end
  end

  defp parse(
    [token | tokens],
    node_state(depth: depth, spaces: spaces, state: :attributes) = state,
    {name, node_annotations, attrs},
    doc
  ) when spaces > 0 do
    case token_to_value(token) do
      {:ok, %Value{value: key_str} = key} ->
        if key.type == :id do
          unless valid_identifier?(key_str) do
            res = [state: state, reason: :invalid_identifier, document: doc, value: key]
            throw {:error, {:invalid_bare_identifier, res}}
          end
        end

        {key_annotations, attrs} =
          case attrs do
            [] ->
              {[], []}

            [r_annotation_token(value: annotation) | attrs] ->
              {[annotation], attrs}

            attrs ->
              {[], attrs}
          end

        key = %{key | annotations: key.annotations ++ key_annotations}

        case trim_leading_space(tokens) do
          {_, [r_equal_token() | tokens]} ->
            case key.annotations do
              [] ->
                :ok

              [_ | _]  ->
                res = [state: state, reason: :invalid_identifier, document: doc]
                throw {:error, {:key_annotations_not_allowed, res}}
            end

            {_, tokens} = trim_leading_space(tokens)
            result =
              case tokens do
                [] ->
                  {:ok, [], tokens}

                [r_open_annotation_token() | tokens] ->
                  case parse(tokens, {:annotation, depth}, [], []) do
                    {:ok, [], _tokens} ->
                      {:error, :empty}

                    {:ok, [token], tokens} ->
                      case token_to_value(token) do
                        {:ok, %Value{value: value}} ->
                          {:ok, [value], tokens}

                        {:error, reason} ->
                          {:error, {:invalid_value, reason}}
                      end

                    {:ok, tokens, _} ->
                      {:error, {:unexpected_tokens, tokens}}

                    {:error, _} = err ->
                      err
                  end

                tokens when is_list(tokens) ->
                  {:ok, [], tokens}
              end

            case result do
              {:ok, value_annotations, tokens} ->
                {_, tokens} = trim_leading_space(tokens)
                case tokens do
                  [] ->
                    res = [state: state, reason: :no_tokens_remaining, document: doc]
                    {:error, {:invalid_parse_state, res}}

                  [token | tokens] ->
                    case token_to_value(token) do
                      {:ok, %Value{} = value} ->
                        value = %{value | annotations: value.annotations ++ value_annotations}
                        parse(
                          tokens,
                          node_state(depth: depth, spaces: 0),
                          {name, node_annotations, [{key, value} | attrs]},
                          doc
                        )

                      {:error, reason} ->
                        res = [state: state, reason: reason, document: doc]
                        {:error, {:invalid_attribute_value, res}}
                    end
                end

              {:error, reason} ->
                res = [state: state, reason: reason, document: doc]
                {:error, {:invalid_attribute_value_annotation, res}}
            end

          {_, _tokens} ->
            # don't use the trimmed tokens, we need to reset the space
            case key do
              %Value{type: :id, value: value} = arg ->
                if valid_identifier?(value) do
                  # reset spaces
                  parse(
                    tokens,
                    node_state(depth: depth, spaces: 0),
                    {name, node_annotations, [arg | attrs]},
                    doc
                  )
                else
                  res = [state: state, reason: :invalid_identifier, document: doc]
                  {:error, {:invalid_bare_identifier, res}}
                end

              %Value{} = arg ->
                parse(
                  tokens,
                  node_state(depth: depth, spaces: 0),
                  {name, node_annotations, [arg | attrs]},
                  doc
                )
            end
        end

      {:error, reason} ->
        res = [state: state, reason: reason, document: doc]
        {:error, {:invalid_attribute_token, res}}
    end
  catch {:error, _} = err ->
    err
  end

  defp parse(
    [],
    node_state(depth: depth) = state,
    {name, node_annotations, attrs},
    doc
  ) do
    case resolve_node_attributes(attrs) do
      {:ok, attrs} ->
        node = %Node{
          name: name,
          annotations: node_annotations,
          attributes: attrs,
          children: nil,
        }
        parse([], default_state(depth: depth), [], [node | doc])

      {:error, reason} ->
        res = [state: state, reason: reason, document: doc]
        {:error, {:invalid_node_attributes, res}}
    end
  end

  defp parse(
    _tokens,
    node_state(state: :children) = state,
    {_name, _node_annotations, _attrs},
    doc
  ) do
    res = [state: state, reason: :node_not_accepting_attributes_now, document: doc]
    {:error, {:invalid_parse_state, res}}
  end

  defp parse([r_close_block_token() | _tokens] = tokens, default_state(), [], doc) do
    handle_parse_exit(tokens, doc)
  end

  defp parse([], default_state() = state, acc, doc) do
    res = [state: state, reason: :no_tokens_remaining, accumulator: acc, document: doc]
    {:error, {:invalid_parse_state, res}}
  end

  defp parse(tokens, default_state() = state, acc, doc) do
    res = [state: state, reason: {:unexpected_tokens, tokens}, accumulator: acc, document: doc]
    {:error, {:invalid_parse_state, res}}
  end

  defp extract_annotations(items, acc \\ [])

  defp extract_annotations([], acc) do
    Enum.reverse(acc)
  end

  defp extract_annotations([r_annotation_token(value: value) | rest], acc) do
    extract_annotations(rest, [value | acc])
  end

  defp extract_annotations([_ | rest], acc) do
    extract_annotations(rest, acc)
  end

  defp handle_parse_exit(rest, doc) do
    doc = Enum.reverse(doc)

    case handle_slashdashes_and_validate(doc, []) do
      {:ok, doc} ->
        {:ok, doc, rest}

      {:error, reason} ->
        {:error, {:unresolved_exit_state, reason}}
    end
  end

  defp resolve_node_attributes(acc) when is_list(acc) do
    result =
      acc
      |> Enum.reverse()
      |> handle_slashdashes_and_validate([])
      |> case do
        {:ok, doc} ->
          doc
          |> Enum.reduce_while({:ok, []}, fn
            r_annotation_token() = token, _acc ->
              {:halt, {:error, {:unresolved_annotation, token}}}

            {%Value{} = key, %Value{} = value}, {:ok, acc} ->
              # deduplicate attributes
              acc =
                Enum.reject(acc, fn
                  {key2, _value} ->
                    key2.value == key.value

                  _ ->
                    false
                end)

              {:cont, {:ok, [{key, value} | acc]}}

            %Value{} = value, {:ok, acc} ->
              {:cont, {:ok, [value | acc]}}
          end)

        {:error, reason} ->
          {:error, {:unresolved_node_attribute, reason}}
      end

    case result do
      {:ok, acc} ->
        {:ok, Enum.reverse(acc)}

      {:error, _} = err ->
        err
    end
  end

  defp unfold_leading_tokens(tokens, count \\ 0, remaining \\ 1)

  defp unfold_leading_tokens([r_space_token() | tokens], count, remaining) do
    unfold_leading_tokens(tokens, count + 1, remaining)
  end

  defp unfold_leading_tokens([r_comment_token(value: {:span, _}) | tokens], count, remaining) do
    unfold_leading_tokens(tokens, count, remaining)
  end

  defp unfold_leading_tokens([r_comment_token(value: {:multiline, _}) | tokens], count, remaining) do
    unfold_leading_tokens(tokens, count, remaining)
  end

  defp unfold_leading_tokens([r_newline_token() | tokens], count, remaining) when remaining > 0 do
    unfold_leading_tokens(tokens, count, remaining - 1)
  end

  defp unfold_leading_tokens([r_comment_token(), r_newline_token() | tokens], count, remaining) when remaining > 0 do
    unfold_leading_tokens(tokens, count, remaining - 1)
  end

  defp unfold_leading_tokens(tokens, count, 0) do
    {:ok, count, tokens}
  end

  defp unfold_leading_tokens([] = tokens, count, _remaining) do
    {:ok, count, tokens}
  end

  defp unfold_leading_tokens(_tokens, _count, _remaining) do
    {:error, :invalid_unfold_sequence}
  end

  defp trim_leading_space(tokens, spaces \\ 0, remaining \\ 0)

  defp trim_leading_space([r_space_token() | tokens], spaces, remaining) do
    trim_leading_space(tokens, spaces + 1, remaining)
  end

  defp trim_leading_space([r_comment_token(value: {:span, _}) | tokens], spaces, remaining) do
    trim_leading_space(tokens, spaces, remaining)
  end

  defp trim_leading_space([r_comment_token(value: {:multiline, _}) | tokens], spaces, remaining) do
    trim_leading_space(tokens, spaces, remaining)
  end

  defp trim_leading_space([r_newline_token() | tokens], spaces, remaining) when remaining > 0 do
    trim_leading_space(tokens, spaces, remaining - 1)
  end

  defp trim_leading_space([r_comment_token(value: {:line, _}), r_newline_token() | tokens], spaces, remaining) when remaining > 0 do
    trim_leading_space(tokens, spaces, remaining - 1)
  end

  defp trim_leading_space([r_fold_token() | tokens], spaces, remaining) do
    trim_leading_space(tokens, spaces, remaining + 1)
  end

  defp trim_leading_space(tokens, spaces, 0) do
    {spaces, tokens}
  end

  defp trim_leading_space_for_slashdash(tokens, spaces \\ 0)

  defp trim_leading_space_for_slashdash([r_space_token() | tokens], spaces) do
    trim_leading_space_for_slashdash(tokens, spaces + 1)
  end

  defp trim_leading_space_for_slashdash([r_comment_token(value: {:span, _}) | tokens], spaces) do
    trim_leading_space_for_slashdash(tokens, spaces)
  end

  defp trim_leading_space_for_slashdash([r_comment_token(value: {:multiline, _}) | tokens], spaces) do
    trim_leading_space_for_slashdash(tokens, spaces)
  end

  defp trim_leading_space_for_slashdash([r_newline_token() | tokens], spaces) do
    trim_leading_space_for_slashdash(tokens, spaces + 1)
  end

  defp trim_leading_space_for_slashdash([r_comment_token(value: {:line, _}), r_newline_token() | tokens], spaces) do
    trim_leading_space_for_slashdash(tokens, spaces + 1)
  end

  defp trim_leading_space_for_slashdash([r_fold_token() | tokens], spaces) do
    trim_leading_space_for_slashdash(tokens, spaces + 1)
  end

  defp trim_leading_space_for_slashdash([], _spaces) do
    {:error, :no_more_tokens}
  end

  defp trim_leading_space_for_slashdash([token | _tokens] = tokens, spaces) do
    is_valid? =
      case token do
        r_close_block_token() -> false
        r_close_annotation_token() -> false
        r_equal_token() -> false
        r_semicolon_token() -> false
        #
        r_dquote_string_token() -> true
        r_open_annotation_token() -> true
        r_term_token() -> true
        r_open_block_token() -> true
      end

    if is_valid? do
      {:ok, {spaces, tokens}}
    else
      {:error, {:unexpected_slashdash_stop_token, token}}
    end
  end

  defp token_to_value(r_term_token(value: value)) do
    decode_term(value)
  end

  defp token_to_value(r_dquote_string_token(value: value)) do
    {:ok, %Value{value: value, type: :string}}
  end

  defp token_to_value(r_raw_string_token(value: value)) do
    {:ok, %Value{value: value, type: :string}}
  end

  defp token_to_value(token) do
    {:error, {:invalid_token_for_value, token}}
  end

  defp decode_term("#true") do
    {:ok, %Value{value: true, type: :boolean}}
  end

  defp decode_term("#false") do
    {:ok, %Value{value: false, type: :boolean}}
  end

  defp decode_term("#null") do
    {:ok, %Value{type: :null, value: nil}}
  end

  defp decode_term("#inf") do
    {:ok, %Value{type: :infinity, value: :infinity}}
  end

  defp decode_term("#-inf") do
    {:ok, %Value{type: :infinity, value: :'-infinity'}}
  end

  defp decode_term("#nan") do
    {:ok, %Value{type: :nan, value: :nan}}
  end

  defp decode_term("#" <> rest) do
    {:ok, %Value{type: :keyword, value: rest}}
  end

  defp decode_term(<<"0b", rest::binary>>) do
    decode_bin_integer(:_, rest)
  end

  defp decode_term(<<"+0b", rest::binary>>) do
    decode_bin_integer(:+, rest)
  end

  defp decode_term(<<"-0b", rest::binary>>) do
    decode_bin_integer(:-, rest)
  end

  defp decode_term(<<"0o", rest::binary>>) do
    decode_oct_integer(:_, rest)
  end

  defp decode_term(<<"+0o", rest::binary>>) do
    decode_oct_integer(:+, rest)
  end

  defp decode_term(<<"-0o", rest::binary>>) do
    decode_oct_integer(:-, rest)
  end

  defp decode_term(<<"0x", rest::binary>>) do
    decode_hex_integer(:_, rest)
  end

  defp decode_term(<<"+0x", rest::binary>>) do
    decode_hex_integer(:+, rest)
  end

  defp decode_term(<<"-0x", rest::binary>>) do
    decode_hex_integer(:-, rest)
  end

  defp decode_term("") do
    {:error, :no_term}
  end

  defp decode_term(term) when is_binary(term) do
    case decode_dec_integer(term) do
      {:ok, value} ->
        {:ok, value}

      {:error, _} ->
        case decode_float(term) do
          {:ok, value} ->
            {:ok, value}

          {:error, _} ->
            {:ok, %Value{value: term, type: :id}}
        end
    end
  end

  defp decode_bin_integer(sign, bin, state \\ :start, acc \\ [])

  defp decode_bin_integer(_sign, <<>>, :start, _acc) do
    {:error, :invalid_bin_integer_format}
  end

  defp decode_bin_integer(sign, <<"_", rest::binary>>, :body, acc) do
    decode_bin_integer(sign, rest, :body, acc)
  end

  defp decode_bin_integer(sign, <<c::utf8, rest::binary>>, _, acc) when c in [?0, ?1] do
    decode_bin_integer(sign, rest, :body, [<<c::utf8>> | acc])
  end

  defp decode_bin_integer(_sign, <<_::utf8, _rest::binary>>, _, _acc) do
    {:error, :invalid_bin_integer_format}
  end

  defp decode_bin_integer(sign, <<>>, :body, acc) do
    case decode_integer(sign, acc, 2) do
      {:ok, value} ->
        {:ok, %{value | format: :bin}}

      {:error, _} = err ->
        err
    end
  end

  defp decode_oct_integer(sign, bin, state \\ :start, acc \\ [])

  defp decode_oct_integer(_sign, <<>>, :start, _acc) do
    {:error, :invalid_oct_integer_format}
  end

  defp decode_oct_integer(sign, <<"_", rest::binary>>, :body, acc) do
    decode_oct_integer(sign, rest, :body, acc)
  end

  defp decode_oct_integer(sign, <<c::utf8, rest::binary>>, _, acc) when c in ?0..?7 do
    decode_oct_integer(sign, rest, :body, [<<c::utf8>> | acc])
  end

  defp decode_oct_integer(_sign, <<_::utf8, _rest::binary>>, _, _acc) do
    {:error, :invalid_oct_integer_format}
  end

  defp decode_oct_integer(sign, <<>>, :body, acc) do
    case decode_integer(sign, acc, 8) do
      {:ok, value} ->
        {:ok, %{value | format: :oct}}

      {:error, _} = err ->
        err
    end
  end

  defp decode_dec_integer(bin, state \\ :start, acc \\ [])

  defp decode_dec_integer(<<>>, :start, _acc) do
    {:error, :invalid_dec_integer_format}
  end

  defp decode_dec_integer(<<"_", rest::binary>>, :body, acc) do
    decode_dec_integer(rest, :body, acc)
  end

  defp decode_dec_integer(<<c::utf8, rest::binary>>, :start, acc) when c in [?+, ?-] do
    decode_dec_integer(rest, :start, [<<c::utf8>> | acc])
  end

  defp decode_dec_integer(<<c::utf8, rest::binary>>, _, acc) when c in ?0..?9 do
    decode_dec_integer(rest, :body, [<<c::utf8>> | acc])
  end

  defp decode_dec_integer(<<_::utf8, _rest::binary>>, _, _acc) do
    {:error, :invalid_dec_integer_format}
  end

  defp decode_dec_integer(<<>>, :body, acc) do
    case decode_integer(nil, acc, 10) do
      {:ok, value} ->
        {:ok, %{value | format: :dec}}

      {:error, _} = err ->
        err
    end
  end

  defp decode_hex_integer(sign, bin, state \\ :start, acc \\ [])

  defp decode_hex_integer(_sign, <<>>, :start, _acc) do
    {:error, :invalid_hex_integer_format}
  end

  defp decode_hex_integer(sign, <<"_", rest::binary>>, :body, acc) do
    decode_hex_integer(sign, rest, :body, acc)
  end

  defp decode_hex_integer(sign, <<c::utf8, rest::binary>>, _, acc) when c in ?0..?9 or
                                                                  c in ?A..?F or
                                                                  c in ?a..?f do
    decode_hex_integer(sign, rest, :body, [<<c::utf8>> | acc])
  end

  defp decode_hex_integer(_sign, <<_::utf8, _rest::binary>>, _, _acc) do
    {:error, :invalid_hex_integer_format}
  end

  defp decode_hex_integer(sign, <<>>, :body, acc) do
    case decode_integer(sign, acc, 16) do
      {:ok, value} ->
        {:ok, %{value | format: :hex}}

      {:error, _} = err ->
        err
    end
  end

  defp decode_integer(nil, acc, radix) do
    case Integer.parse(IO.iodata_to_binary(Enum.reverse(acc)), radix) do
      {int, ""} ->
        {:ok, %Value{value: int, type: :integer}}

      {_int, _} ->
        {:error, :invalid_integer_format}

      :error ->
        {:error, :invalid_integer_format}
    end
  end

  defp decode_integer(sign, acc, radix) do
    case decode_integer(nil, acc, radix) do
      {:ok, %Value{} = value} ->
        # handle the explicit sign, so why?
        # erlang otp27 introduced +0.0 and -0.0, so we need to handle those moving forward
        case sign do
          :_ -> {:ok, value}
          :+ -> {:ok, %{value | value: +value.value}}
          :- -> {:ok, %{value | value: -value.value}}
        end
      {:error, _} = err ->
        err
    end
  end

  defp decode_float(value) when is_binary(value) do
    case parse_float_string(value) do
      {:ok, value} ->
        case Decimal.parse(value) do
          {%Decimal{} = decimal, ""} ->
            {:ok, %Value{value: decimal, type: :float}}

          {%Decimal{}, _} ->
            {:error, :invalid_float_format}

          :error ->
            {:error, :invalid_float_format}
        end

      {:error, _} = err ->
        err
    end
  end

  defp handle_slashdashes_and_validate([:slashdash], _acc) do
    #handle_slashdashes_and_validate([], acc)
    {:error, :slashdash_nothing}
  end

  defp handle_slashdashes_and_validate(
    [:slashdash, term | tokens],
    acc
  ) do
    case term do
      %Kuddle.Node{} ->
        handle_slashdashes_and_validate(tokens, acc)

      %Kuddle.Value{} ->
        handle_slashdashes_and_validate(tokens, acc)

      {%Kuddle.Value{}, %Kuddle.Value{}} ->
        handle_slashdashes_and_validate(tokens, acc)

      {:raw_block, _} ->
        handle_slashdashes_and_validate(tokens, acc)

      term ->
        {:error, {:unexpected_slashdash_target, term}}
    end
  end

  defp handle_slashdashes_and_validate([{:raw_block, _} | _tokens], _acc) do
    {:error, :raw_block_in_document}
  end

  defp handle_slashdashes_and_validate([term | tokens], acc) do
    handle_slashdashes_and_validate(tokens, [term | acc])
  end

  defp handle_slashdashes_and_validate([], acc) do
    {:ok, Enum.reverse(acc)}
  end
end

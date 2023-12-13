defmodule Kuddle.V1.TokenizerTest do
  use ExUnit.Case, async: true

  import Kuddle.V1.Tokenizer

  describe "tokenize/1 (good form)" do
    test "cannot tokenize out of range utf-8 value" do
      assert {:ok, [{:term, "n", _}], "\u{10FFFF}"} = tokenize("n\u{10FFFF}")
      assert {:ok, [{:term, "n\u{10FFFE}", _}], ""} = tokenize("n\u{10FFFE}")
    end

    test "can tokenize an empty raw string" do
      assert {:ok, tokens, ""} = tokenize("r\"\"")

      assert [
        {:raw_string, "", _}
      ] = tokens
    end

    test "can tokenize a raw string with multiple #" do
      assert {:ok, tokens, ""} = tokenize("r###\"\"###")

      assert [
        {:raw_string, "", _}
      ] = tokens
    end

    test "can tokenize a multiline raw string" do
      assert {:ok, tokens, ""} = tokenize(
        """
        r"
        \\n
        "
        """
      )
      assert [
        {:raw_string, "\n\\n\n", _},
        {:nl, 1, _}
      ] = tokens
    end

    test "correctly tokenizes nested children" do
      assert {:ok, tokens, ""} = tokenize(
        """
        node1 {
          node2 {
            node
          }
        }
        """
      )

      assert [
        {:term, "node1", {_, 1, 1}},
        {:space, 1, {_, 1, 6}},
        {:open_block, 0, {_, 1, 7}},
        {:nl, 1, {_, 1, 8}},
        {:space, 2, {_, 2, 1}},
        {:term, "node2", {_, 2, 3}},
        {:space, 1, {_, 2, 8}},
        {:open_block, 0, {_, 2, 9}},
        {:nl, 1, {_, 2, 10}},
        {:space, 4, {_, 3, 1}},
        {:term, "node", {_, 3, 5}},
        {:nl, 1, {_, 3, 9}},
        {:space, 2, {_, 4, 1}},
        {:close_block, 0, {_, 4, 3}},
        {:nl, 1, {_, 4, 4}},
        {:close_block, 0, {_, 5, 1}},
        {:nl, 1, {_, 5, 2}}
      ] = tokens
    end
  end

  describe "tokenize/1 (malformed)" do
    test "correctly aborts on unclosed strings" do
      assert {:error, _} = tokenize(
        """
        "abc
        """
      )
    end
  end
end

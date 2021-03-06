defmodule Kuddle.TokenizerTest do
  use ExUnit.Case, async: true

  import Kuddle.Tokenizer

  describe "tokenize/1 (good form)" do
    test "cannot tokenize out of range utf-8 value" do
      assert {:ok, [{:term, "n"}], "\u{10FFFF}"} = tokenize("n\u{10FFFF}")
      assert {:ok, tokens, ""} = tokenize("n\u{10FFFE}")
    end

    test "can tokenize an empty raw string" do
      assert {:ok, tokens, ""} = tokenize("r\"\"")

      assert [
        {:raw_string, ""}
      ] = tokens
    end

    test "can tokenize a raw string with multiple #" do
      assert {:ok, tokens, ""} = tokenize("r###\"\"###")

      assert [
        {:raw_string, ""}
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
        {:raw_string, "\n\\n\n"},
        {:nl, 1}
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
        {:term, "node1"},
        {:space, 1},
        {:open_block, 0},
        {:nl, 1},
        {:space, 2},
        {:term, "node2"},
        {:space, 1},
        {:open_block, 0},
        {:nl, 1},
        {:space, 4},
        {:term, "node"},
        {:nl, 1},
        {:space, 2},
        {:close_block, 0},
        {:nl, 1},
        {:close_block, 0},
        {:nl, 1}
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

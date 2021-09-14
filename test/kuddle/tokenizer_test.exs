defmodule Kuddle.TokenizerTest do
  use ExUnit.Case

  import Kuddle.Tokenizer

  describe "tokenize/1" do
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
        {:space, {" ", 1}},
        {:open_block, 0},
        {:nl, 1},
        {:space, {" ", 2}},
        {:term, "node2"},
        {:space, {" ", 1}},
        {:open_block, 0},
        {:nl, 1},
        {:space, {" ", 4}},
        {:term, "node"},
        {:nl, 1},
        {:space, {" ", 2}},
        {:close_block, 0},
        {:nl, 1},
        {:close_block, 0},
        {:nl, 1}
      ] = tokens
    end
  end
end

defmodule Kuddle.V2.TokenizerTest do
  use Kuddle.Support.Case, async: true

  alias Kuddle.V2.Tokenizer

  describe "strings" do
    test "can handle single line strings" do
      assert {:ok, [
        {:term, "str", _},
        {:space, _, _},
        {:dquote_string, "", _},
        {:nl, _, _},
        {:term, "str", _},
        {:space, _, _},
        {:dquote_string, "\n", _},
        {:nl, _, _},
      ], ""} = Tokenizer.tokenize("""
      str ""
      str "\\n"
      """)
    end

    test "can handle multiline strings" do
      assert {:ok, [
        {:term, "str", _},
        {:space, _, _},
        {:dquote_string, "", _},
        {:nl, _, _},
        {:term, "str", _},
        {:space, _, _},
        {:dquote_string, "\n", _},
        {:nl, _, _},
        {:term, "str", _},
        {:space, _, _},
        {:dquote_string, "  Two-spaces", _},
        {:nl, _, _},
        {:term, "str", _},
        {:space, _, _},
        {:dquote_string, "Should have no indent", _},
        {:nl, _, _},
      ], ""} = Tokenizer.tokenize("""
      str "
      "
      str "
      \\n
      "
      str "
        Two-spaces
      "
      str "
        Should have no indent
        "
      """)
    end

    test "will error given a string with a insufficient indent" do
      assert {:error, {:invalid_multline_string, reason: {:incomplete_dedentation, line: ~c"Outdentation"}}} =
        Tokenizer.tokenize("""
        str "
        Outdentation
            "
        """)
    end
  end

  describe "annotations" do
    test "can handle different annotations" do
      assert {:ok, [
        {:open_annotation, _, _},
        {:close_annotation, _, _},
        {:nl, _, _},
        {:open_annotation, _, _},
        {:space, _, _},
        {:close_annotation, _, _},
        {:nl, _, _},
        {:open_annotation, _, _},
        {:term, "type", _},
        {:close_annotation, _, _},
        {:nl, _, _},
        {:open_annotation, _, _},
        {:dquote_string, "quoted annotation", _},
        {:close_annotation, _, _},
        {:nl, _, _},
      ], ""} = Tokenizer.tokenize("""
      ()
      (    )
      (type)
      ("quoted annotation")
      """)
    end
  end

  describe "comments with folds" do
    test "can inline after fold" do
      assert {:ok, [
        {:term, "node", _},
        {:space, _, _},
        {:fold, _, _},
        {:space, _, _},
        {:comment, _, _},
        {:nl, _, _},
        {:space, _, _},
        {:term, "arg", _},
        {:space, _, _},
        {:fold, _, _},
        {:comment, _, _},
        {:nl, _, _},
        {:space, _, _},
        {:term, "arg2", _},
        {:nl, _, _},
      ], ""} = Tokenizer.tokenize("""
        node \\   // comment
          arg \\// comment
          arg2
        """
      )
    end
  end

  describe "equals" do
    test "correctly handles ascii `=`" do
      assert {:ok, [
        {:=, _, _},
      ], ""} = Tokenizer.tokenize("=")
    end

    test "correctly handles utf8 equals" do
      assert {:ok, [
        {:=, _, _},
        {:space, _, _},
        {:=, _, _},
        {:space, _, _},
        {:=, _, _},
        {:nl, _, _},
      ], ""} = Tokenizer.tokenize("""
      \u{FE66} \u{FF1D} \u{1F7F0}
      """)
    end
  end

  describe "semicolon" do
    test "can correctly handle semicolons" do
      assert {:ok, [
        {:term, "node", _},
        {:space, _, _},
        {:open_block, _, _},
        {:term, "foo", _},
        {:sc, _, _},
        {:term, "bar", _},
        {:sc, _, _},
        {:term, "baz", _},
        {:close_block, _, _},
        {:nl, _, _},
      ], ""} = Tokenizer.tokenize("""
      node {foo;bar;baz}
      """)
    end
  end
end
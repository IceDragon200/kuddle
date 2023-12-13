defmodule Kuddle.V2.DecoderTest do
  use Kuddle.Support.Case, async: true

  alias Kuddle.V2.Decoder
  alias Kuddle.Node

  describe "comments" do
    test "can parse a single line content terminated immediately" do
      assert {:ok, [], []} = Decoder.decode("//")
    end

    test "can parse a single line content terminated by newline" do
      assert {:ok, [], []} = Decoder.decode("//\n")
    end
  end

  describe "double quoted strings" do
    test "can parse double quoted strings" do
      assert {:ok, [
        %Node{
          name: "str",
          attributes: [
            %{type: :string, value: "This is a double quoted string"},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      str "This is a double quoted string"
      """)
    end

    test "can parse double quoted strings with basic escape sequences" do
      assert {:ok, [
        %Node{
          name: "str",
          attributes: [
            %{type: :string, value: "\"\r\n\b\f\s\t\\/"},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      str "\\"\\r\\n\\b\\f\\s\\t\\\\/\\         "
      """)
    end

    test "can parse a multiline empty string" do
      assert {:ok, [
        %Node{
          name: "str",
          attributes: [
            %{type: :string, value: ""},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      str "
      "
      """)
    end

    test "can parse a multiline empty string (with tailing spaces)" do
      assert {:ok, [
        %Node{
          name: "str",
          attributes: [
            %{type: :string, value: ""},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      str "
          "
      """)
    end

    test "can parse a multiline empty string (with additional newlines)" do
      assert {:ok, [
        %Node{
          name: "str",
          attributes: [
            %{type: :string, value: "\n"},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      str "

      "
      """)
    end

    test "can parse a multiline string" do
      assert {:ok, [
        %Node{
          name: "str",
          attributes: [
            %{type: :string, value: """
            This string has:
            * multiple
            * cool
            * lines
            """},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      str "
      This string has:
      * multiple
      * cool
      * lines
      "
      """)
    end

    test "can error on a unterminated string" do
      assert {:error, {:unterminated_dquote_string, _}} = Decoder.decode("""
      str "
      """)
    end
  end

  describe "raw strings" do
    test "can decode raw strings (single #)" do
      assert {:ok, [
        %Node{
          name: "raw",
          attributes: [
            %{type: :string, value: "This is a raw string"},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      raw #"This is a raw string"#
      """)
    end

    test "can decode raw strings (multiple #)" do
      assert {:ok, [
        %Node{
          name: "raw",
          attributes: [
            %{type: :string, value: "This is a raw string with a lot of hashes"},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      raw ######"This is a raw string with a lot of hashes"######
      """)
    end

    test "can decode raw strings (with dedentation)" do
      assert {:ok, [
        %Node{
          name: "raw",
          attributes: [
            %{type: :string, value: """
            Line 1
              Line 2
                Line 3
              Line 4
            Line 5
            """},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      raw #"
        Line 1
          Line 2
            Line 3
          Line 4
        Line 5
        "#
      """)
    end

    test "v1 raw strings should return an error" do
      assert {:error, {:invalid_identifier, _}} = Decoder.decode("""
      raw r#"
      This shouldn't parse
      "#
      """)
    end
  end

  describe "keywords" do
    test "can decode valid keywords" do
      assert {:ok, [
        %Node{
          name: "bool-true",
          attributes: [
            %{type: :boolean, value: true},
          ],
          children: nil
        },
        %Node{
          name: "bool-false",
          attributes: [
            %{type: :boolean, value: false},
          ],
          children: nil
        },
        %Node{
          name: "term-null",
          attributes: [
            %{type: :null, value: nil},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      bool-true #true
      bool-false #false
      term-null #null
      """)
    end

    test "can recognize unsupported keywords" do
      # These should typically error
      assert {:ok, [
        %Node{
          name: "keyword",
          attributes: [
            %{type: :keyword, value: "not-really"},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      keyword #not-really
      """)
    end
  end
end

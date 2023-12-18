defmodule Kuddle.V2.DecoderTest do
  use Kuddle.Support.Case, async: true

  alias Kuddle.V2.Decoder
  alias Kuddle.Value
  alias Kuddle.Node

  describe "comments" do
    test "can parse a single line content terminated immediately" do
      assert {:ok, [], []} = Decoder.decode("//")
    end

    test "can parse a single line content terminated by newline" do
      assert {:ok, [], []} = Decoder.decode("//\n")
    end

    test "can parse single line comment with node prior" do
      assert {:ok, [
        %Node{name: "node", attributes: [], children: nil},
        %Node{name: "node2", attributes: [], children: nil},
      ], []} = Decoder.decode("""
      node //
      node2
      """)
    end

    test "can folded comments with single arg" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: [],
          attributes: [
            %Value{type: :id, value: "arg"},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      node \\ //
        arg
      """)
    end

    test "can folded comments with multiple args" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: [],
          attributes: [
            %Value{type: :id, value: "arg"},
            %Value{type: :id, value: "arg2"},
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      node \\ // Hello
        arg \\ // World
        arg2
      """)
    end
  end

  describe "nodes" do
    test "can parse annotated node" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: ["type"],
          attributes: [],
          children: nil
        },
      ], []} = Decoder.decode("""
      (type)node
      """)
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

    test "can parse annotated string" do
      assert {:ok, [
        %Node{
          name: "str",
          attributes: [
            %Value{
              type: :id,
              value: "Hello",
              annotations: ["type"],
            },
          ],
          annotations: [],
          children: nil
        }
      ], []} = Decoder.decode("""
      str (type)Hello
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
            %{type: :string, value: ""},
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
            %{type: :string, value: "This string has:\n* multiple\n* cool\n* lines"},
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
            %{type: :string, value: "Line 1\n  Line 2\n    Line 3\n  Line 4\nLine 5"},
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

  describe "spaces" do
    test "can handle spaces around key-value pairs" do
      assert {:ok, [
        %Node{
          name: "node",
          attributes: [
            {
              %Value{type: :id, format: :plain, value: "foo"},
              %Value{type: :id, format: :plain, value: "bar"},
            }
          ],
          children: nil
        }
      ], []} = Decoder.decode("""
      node foo = bar
      """)
    end

    test "can handle around properties with type annotations" do
      assert {:ok, [
        %Node{
          name: "node",
          attributes: [
            {
              %Value{type: :id, format: :plain, value: "foo"},
              %Value{
                type: :id,
                format: :plain,
                annotations: ["type"],
                value: "bar"
              },
            }
          ],
          children: nil
        }
      ], []} = Decoder.decode("""
      node foo =(type) bar
      """)
    end
  end

  describe "semicolons" do
    test "can handle a single line node" do
      assert {:ok, [
        %Node{
          name: "node",
          children: [
            %Node{name: "foo", attributes: [], children: nil},
            %Node{name: "bar", attributes: [], children: nil},
            %Node{name: "baz", attributes: [], children: nil},
          ]
        }
      ], []} = Decoder.decode("""
      node {foo;bar;baz}
      """)
    end
  end
end

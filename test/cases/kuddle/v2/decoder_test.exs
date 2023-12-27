defmodule Kuddle.V2.DecoderTest do
  use Kuddle.Support.Case, async: true

  alias Kuddle.V2.Decoder
  alias Kuddle.Value
  alias Kuddle.Node

  describe "single line comments" do
    test "can parse a single line comment terminated by EOF" do
      assert {:ok, [], []} = Decoder.decode("//")
    end

    test "can parse a single line comment terminated by newline" do
      assert {:ok, [], []} = Decoder.decode("//\n")
      assert {:ok, [], []} = Decoder.decode("//\r")
      assert {:ok, [], []} = Decoder.decode("//\r\n")
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

    test "can handle folded comments with single arg for node" do
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

    test "can handle folded comments with multiple args" do
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

  describe "span comments" do
    test "can handle span comments" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: [],
          attributes: [],
          children: nil
        },
        %Node{
          name: "node2",
          annotations: [],
          attributes: [],
          children: nil
        },
      ], []} = Decoder.decode("""
      node /* Hello World */
      /* Goodbye Universe */ node2
      """)
    end

    test "can handle span comments within annotations" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: ["something"],
          attributes: [],
          children: nil
        },
      ], []} = Decoder.decode("""
      (/* Hello World */ something /* something else */)node
      """)
    end

    test "can handle span comments around annotations" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: ["something"],
          attributes: [],
          children: nil
        },
      ], []} = Decoder.decode("""
      /* Hello World */(something)/* something else */node
      """)
    end

    test "can handle span comments before property" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: [],
          attributes: [
            {
              %Kuddle.Value{value: "prop", annotations: [], type: :id, format: :plain},
              %Kuddle.Value{value: "value", annotations: [], type: :id, format: :plain},
            }
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      node /* comment */prop=value
      """)
    end

    test "can handle span comments within property" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: [],
          attributes: [
            {
              %Kuddle.Value{value: "prop", annotations: [], type: :id, format: :plain},
              %Kuddle.Value{value: "value", annotations: [], type: :id, format: :plain},
            }
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      node prop/* comment */=/* comment 2 */value
      """)
    end

    test "can handle span comments within property with annotations" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: ["something"],
          attributes: [
            {
              %Kuddle.Value{value: "prop", annotations: [], type: :id, format: :plain},
              %Kuddle.Value{value: "value", annotations: ["vtype"], type: :id, format: :plain},
            }
          ],
          children: nil
        },
        %Node{
          name: "node2",
          annotations: ["something2"],
          attributes: [
            {
              %Kuddle.Value{value: "prop2", annotations: [], type: :id, format: :plain},
              %Kuddle.Value{value: "value2", annotations: ["vtype2"], type: :id, format: :plain},
            }
          ],
          children: nil
        },
      ], []} = Decoder.decode("""
      (something)node prop/* comment */=/* comment 2 */(vtype)/* comment 3 */value
      (something2)node2 prop2   /* comment A */   =    /* comment B */   (vtype2)  /* comment C */ value2
      """)
    end
  end

  describe "nodes" do
    test "can parse nested nodes" do
      assert {:ok, [
        %Node{
          name: "node1",
          annotations: [],
          attributes: [],
          children: [
            %Node{
              name: "node2",
              annotations: [],
              attributes: [],
              children: [
                %Node{
                  name: "node3",
                  annotations: [],
                  attributes: [],
                  children: [
                    %Node{
                      name: "node4a",
                      annotations: [],
                      attributes: [],
                      children: nil
                    },
                    %Node{
                      name: "node4b",
                      annotations: [],
                      attributes: [],
                      children: nil
                    },
                    %Node{
                      name: "node4c",
                      annotations: [],
                      attributes: [],
                      children: nil
                    }
                  ]
                }
              ]
            }
          ]
        },
      ], []} = Decoder.decode("""
      node1 {
        node2 {
          node3 {
            node4a
            node4b
            node4c
          }
        }
      }
      """)
    end

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

    test "can parse annotated node with generous spacing" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: ["type"],
          attributes: [],
          children: nil
        },
      ], []} = Decoder.decode("""
      (   type     )     node
      """)
    end

    test "can gracefully handle unclosed node block" do
      assert {:error, {:invalid_parse_state, _}} = Decoder.decode("""
      node {
      """)
    end

    test "can gracefully handle unclosed nested node block" do
      assert {:error, {:invalid_parse_state, _}} = Decoder.decode("""
      node {
        node2 {

      }
      """)
    end

    test "can gracefully handle incomplete property" do
      assert {:error, {:invalid_parse_state, _}} = Decoder.decode("node a=")
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

  describe "identifiers" do
    test "will prevent use of reserved identifiers for nodes" do
      assert {:error, {:invalid_identifier, _}} = Decoder.decode("true")
      assert {:error, {:invalid_identifier, _}} = Decoder.decode("false")
      assert {:error, {:invalid_identifier, _}} = Decoder.decode("null")
    end

    test "will prevent use of reserved identifiers for nested nodes" do
      assert {:error, {:invalid_identifier, _}} = Decoder.decode("""
      node {
        true
      }
      """)
      assert {:error, {:invalid_identifier, _}} = Decoder.decode("""
      node {
        false
      }
      """)
      assert {:error, {:invalid_identifier, _}} = Decoder.decode("""
      node {
        null
      }
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

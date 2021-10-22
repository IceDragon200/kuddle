defmodule Kuddle.DecoderTest do
  use ExUnit.Case, async: true

  alias Kuddle.Decoder
  alias Kuddle.Node

  describe "decode/1" do
    test "can decode scientific exponent" do
      value = Decimal.new("1.23e-1000")

      assert {:ok, [
        %Node{
          name: "node",
          attributes: [
            %{type: :float, value: ^value}
          ],
          children: nil,
        }
      ], []} = Decoder.decode("node 1.23E-1000")
    end

    test "can decode node annotation" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: ["frying_pan"],
          attributes: [
            %{type: :string, value: "bacon"}
          ],
          children: nil
        }
      ], []} = Decoder.decode("(frying_pan)node \"bacon\"")
    end

    test "can decode an argument annotation" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: [],
          attributes: [
            %{
              type: :string,
              annotations: ["u8string"],
              value: "bacon"
            }
          ],
          children: nil
        }
      ], []} = Decoder.decode("node (u8string)\"bacon\"")
    end

    test "can decode annotations from readme example" do
      assert {:ok, [node], []} =
        Decoder.decode("""
        numbers (u8)10 (i32)20 myfloat=(f32)1.5 {
          strings (uuid)"123e4567-e89b-12d3-a456-426614174000" (date)"2021-02-03" filter=(regex)r"$\\d+"
          (author)person name="Alex"
        }
        """)

      float_value = Decimal.new("1.5")

      assert %{
        name: "numbers",
        attributes: [
          %{
            type: :integer,
            annotations: ["u8"],
            value: 10,
            format: :dec,
          },
          %{
            type: :integer,
            annotations: ["i32"],
            value: 20,
            format: :dec,
          },
          {
            %{
              type: :id,
              annotations: [],
              value: "myfloat",
            },
            %{
              type: :float,
              annotations: ["f32"],
              value: ^float_value,
            }
          },
        ],
        children: [
          %{
            name: "strings",
            annotations: [],
            attributes: [
              %{
                type: :string,
                annotations: ["uuid"],
                value: "123e4567-e89b-12d3-a456-426614174000",
              },
              %{
                type: :string,
                annotations: ["date"],
                value: "2021-02-03",
              },
              {
                %{
                  type: :id,
                  annotations: [],
                  value: "filter"
                },
                %{
                  type: :string,
                  annotations: ["regex"],
                  value: "$\\d+"
                }
              }
            ]
          },
          %{
            name: "person",
            annotations: ["author"],
            attributes: [
              {
                %{
                  type: :id,
                  annotations: [],
                  value: "name",
                },
                %{
                  type: :string,
                  annotations: [],
                  value: "Alex",
                }
              }
            ]
          }
        ]
      } = node
    end

    test "correctly slashdashes node" do
      assert {:ok, [
        %Node{
          name: "showme",
          annotations: [],
          attributes: [
          ],
          children: [
            %Node{
              name: "visible",
              annotations: [],
              attributes: [],
              children: nil,
            }
          ]
        }
      ], []} = Decoder.decode("""
      /- hideme {
        hidden
      }
      showme {
        visible
      }
      """)
    end

    test "can handle folded arguments" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: [],
          attributes: [
            %{
              type: :string,
              annotations: [],
              value: "arg1"
            },
            %{
              type: :string,
              annotations: [],
              value: "arg2"
            },
            %{
              type: :string,
              annotations: [],
              value: "arg3"
            }
          ],
          children: nil
        }
      ], []} = Decoder.decode("""
      node "arg1" \\
           "arg2" \\
           "arg3"
      """)
    end

    test "can handle folded properties" do
      assert {:ok, [
        %Node{
          name: "node",
          annotations: [],
          attributes: [
            {
              %{
                type: :id,
                annotations: [],
                value: "prop1"
              },
              %{
                type: :integer,
                annotations: [],
                value: 1
              },
            },
            {
              %{
                type: :id,
                annotations: [],
                value: "prop2"
              },
              %{
                type: :integer,
                annotations: [],
                value: 2
              },
            },
            {
              %{
                type: :id,
                annotations: [],
                value: "prop3"
              },
              %{
                type: :integer,
                annotations: [],
                value: 3
              },
            }
          ],
          children: nil
        }
      ], []} = Decoder.decode("""
      node prop1=1 \\
           prop2 \\
           = 2 \\
           prop3 = \\
            3
      """)
    end
  end
end

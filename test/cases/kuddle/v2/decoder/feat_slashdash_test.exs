defmodule Kuddle.V2.Decoder.FeatSlashdashTest do
  use Kuddle.Support.Case, async: true

  alias Kuddle.V2.Decoder
  alias Kuddle.Value
  alias Kuddle.Node

  # draft.5
  describe "slashdash" do
    test "slashdash can exclude entire node" do
      assert {:ok, [], []} = Decoder.decode("""
      /- node prop="abc" {
        child "arg1" "arg2"
      }
      """)
    end

    test "slashdash can exclude entire argument" do
      assert {:ok, [
        %Node{
          name: "node",
          attributes: [
            %Value{type: :string, value: "arg1"},
            %Value{type: :string, value: "arg2"},
          ],
          children: nil
        }
      ], []} = Decoder.decode("""
      node "arg1" /- "argz" "arg2"
      """)
    end

    test "slashdash can exclude entire property" do
      assert {:ok, [
        %Node{
          name: "node",
          attributes: [
            {%Value{type: :id, value: "prop1"}, %Value{type: :string, value: "arg1"}},
            {%Value{type: :id, value: "prop2"}, %Value{type: :string, value: "arg2"}},
          ],
          children: nil
        }
      ], []} = Decoder.decode("""
      node prop1="arg1" /- propz="argz" prop2="arg2"
      """)
    end

    test "slashdash can exclude children block" do
      assert {:ok, [
        %Node{
          name: "node",
          attributes: [
            {%Value{type: :id, value: "prop1"}, %Value{type: :string, value: "arg1"}},
            {%Value{type: :id, value: "prop2"}, %Value{type: :string, value: "arg2"}},
            %Value{type: :string, value: "arg3"},
          ],
          children: nil
        },
        %Node{
          name: "node2",
          children: [
            %Node{
              name: "node5"
            },
          ]
        }
      ], []} = Decoder.decode("""
      node prop1="arg1" prop2="arg2" "arg3" /- {
        node2
        node3
        node4
      }
      node2 {
        node5
      }
      """)
    end

    test "slashdash can exclude children blocks" do
      assert {:ok, [
        %Node{
          name: "node",
          attributes: [
          ],
          children: [
            %Node{name: "nodeY"},
          ]
        },
      ], []} = Decoder.decode("""
      node /- {
        nodeX
      } \
      {
        nodeY
      }
      """)
    end
  end
end

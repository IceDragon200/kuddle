defmodule Kuddle.V1.PathTest do
  use Kuddle.Support.Case, async: true

  alias Kuddle.V1, as: Mod
  alias Kuddle.Node

  describe "select/2" do
    test "retrieve a node by name" do
      {:ok, doc, _} = Kuddle.decode("""
        node {
          node2 {
            node3 {
            }
          }
        }
        """)

      assert [%Node{name: "node", children: [%Node{name: "node2"}]}] = Mod.select(doc, ["node"])
      assert [%Node{name: "node2", children: [%Node{name: "node3"}]}] = Mod.select(doc, ["node2"])
      assert [%Node{name: "node3", children: []}] = Mod.select(doc, ["node3"])
    end

    test "retrieve a node by attribute name" do
      {:ok, doc, _} = Mod.decode("""
        node id="egg" {
          node2 name="bacon" {
            node3 title="fries" {
            }
          }
        }
        """)

      assert [%Node{name: "node", children: [%Node{name: "node2"}]}] = Mod.select(doc, [{:attr, "id"}])
      assert [%Node{name: "node2", children: [%Node{name: "node3"}]}] = Mod.select(doc, [{:attr, "name"}])
      assert [%Node{name: "node3", children: []}] = Mod.select(doc, [{:attr, "title"}])
    end

    test "retrieve a node by attribute name and value" do
      {:ok, doc, _} = Mod.decode("""
        node id="egg" {
          node2 name="bacon" {
            node3 title="fries" {
            }
          }
        }
        """)

      assert [%Node{name: "node", children: [%Node{name: "node2"}]}] = Mod.select(doc, [{:attr, "id", "egg"}])
      assert [] = Mod.select(doc, [{:attr, "id", "bacon"}])

      assert [%Node{name: "node2", children: [%Node{name: "node3"}]}] = Mod.select(doc, [{:attr, "name", "bacon"}])
      assert [] = Mod.select(doc, [{:attr, "name", "fries"}])

      assert [%Node{name: "node3", children: []}] = Mod.select(doc, [{:attr, "title", "fries"}])
      assert [] = Mod.select(doc, [{:attr, "title", "egg"}])
    end

    test "retrieve a node by value" do
      {:ok, doc, _} = Mod.decode("""
        node 1 2 3 {
          node2 "a" "b" "c" {
            node3 true {
            }
          }
        }
        """)

      assert [%Node{name: "node", children: [%Node{name: "node2"}]}] = Mod.select(doc, [{:value, 1}])
      assert [%Node{name: "node2", children: [%Node{name: "node3"}]}] = Mod.select(doc, [{:value, "a"}])
      assert [%Node{name: "node3", children: []}] = Mod.select(doc, [{:value, true}])
    end

    test "retrieve a node by explicit name" do
      {:ok, doc, _} = Mod.decode("""
        node {
          node2 {
            node3 {
            }
          }
        }
        """)

      assert [%Node{name: "node", children: [%Node{name: "node2"}]}] = Mod.select(doc, [{:node, "node"}])
      assert [%Node{name: "node2", children: [%Node{name: "node3"}]}] = Mod.select(doc, [{:node, "node2"}])
      assert [%Node{name: "node3", children: []}] = Mod.select(doc, [{:node, "node3"}])
    end

    test "retrieve a node by node matcher" do
      {:ok, doc, _} = Mod.decode("""
        node id="egg" {
          node2 name="bacon" {
            node3 title="fries" {
            }
          }
        }
        """)

      assert [%Node{name: "node", children: [%Node{name: "node2"}]}] = Mod.select(doc, [{:node, "node", [{"id", "egg"}]}])
      assert [%Node{name: "node", children: [%Node{name: "node2"}]}] = Mod.select(doc, [{:node, "node", [{:attr, "id"}]}])
      assert [%Node{name: "node", children: [%Node{name: "node2"}]}] = Mod.select(doc, [{:node, "node", [{:attr, "id", "egg"}]}])

      assert [%Node{name: "node2", children: [%Node{name: "node3"}]}] = Mod.select(doc, [{:node, "node2", [{"name", "bacon"}]}])
      assert [%Node{name: "node2", children: [%Node{name: "node3"}]}] = Mod.select(doc, [{:node, "node2", [{:attr, "name"}]}])
      assert [%Node{name: "node2", children: [%Node{name: "node3"}]}] = Mod.select(doc, [{:node, "node2", [{:attr, "name", "bacon"}]}])

      assert [%Node{name: "node3"}] = Mod.select(doc, [{:node, "node3", [{"title", "fries"}]}])
      assert [%Node{name: "node3"}] = Mod.select(doc, [{:node, "node3", [{:attr, "title"}]}])
      assert [%Node{name: "node3"}] = Mod.select(doc, [{:node, "node3", [{:attr, "title", "fries"}]}])

      assert [] = Mod.select(doc, [{:node, "node3", [{"title", "bacon"}]}])
      assert [] = Mod.select(doc, [{:node, "node3", [{:attr, "name"}]}])
      assert [] = Mod.select(doc, [{:node, "node3", [{:attr, "title", "bacon"}]}])
    end
  end
end

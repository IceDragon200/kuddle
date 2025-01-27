defmodule KuddleTest do
  use Kuddle.Support.Case

  doctest Kuddle

  describe "decode/1" do
    test "can decode a KDL document using the V2 module as default" do
      assert {:ok, [%Kuddle.Node{name: "node"}], []} = Kuddle.decode("node")
    end
  end

  describe "encode/1" do
    test "can encode a KDL document using the V2 module as default" do
      assert {:ok, "node\n"} = Kuddle.encode([%Kuddle.Node{name: "node"}])
    end
  end
end

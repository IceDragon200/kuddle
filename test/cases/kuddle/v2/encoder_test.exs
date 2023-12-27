defmodule Kuddle.V2.EncoderTest do
  use Kuddle.Support.Case, async: true

  alias Kuddle.V2.Encoder
  alias Kuddle.V2.Decoder

  describe "annotations" do
    test "will encode node annotations" do
      assert """
      (type1)node
      """ == cycle_encode("""
      (type1)node
      """)
    end

    test "will encode annotations on properties" do
      assert """
      node (type1)attr1 attr2=(type3)abc
      """ == cycle_encode("""
      node     (type1)  attr1     attr2  =  (type3)  abc
      """)
    end
  end

  defp cycle_encode(str) do
    assert {:ok, doc, []} = Decoder.decode(str)
    assert {:ok, blob} = Encoder.encode(doc)
    blob
  end
end

defmodule Kuddle.DecoderTest do
  use ExUnit.Case, async: true

  alias Kuddle.Decoder

  describe "decode/1" do
    test "can decode scientific exponent" do
      assert {:ok, [
        {:node, "node", [%{type: :float, value: 1.23e-1000}], nil}
      ], []} = Kuddle.Decoder.decode("node 1.23E-1000")
    end
  end
end

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
      ], []} = Kuddle.Decoder.decode("node 1.23E-1000")
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
      ], []} = Kuddle.Decoder.decode("(frying_pan)node \"bacon\"")
    end
  end
end

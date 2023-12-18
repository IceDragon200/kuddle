defmodule Kuddle.V2.UtilsTest do
  use Kuddle.Support.Case, async: true

  alias Kuddle.V2.Utils

  import Kuddle.Tokens

  describe "split_up_to_newline/2" do
    test "can split a string up to a newline" do
      meta = r_token_meta()

      assert {:ok, "a", "\nb", _meta} = Utils.split_up_to_newline("a\nb", meta)
      assert {:ok, "a", "\rb", _meta} = Utils.split_up_to_newline("a\rb", meta)
      assert {:ok, "a", "\r\nb", _meta} = Utils.split_up_to_newline("a\r\nb", meta)
    end
  end
end

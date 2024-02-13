defmodule Kuddle.V2.UtilsTest do
  use Kuddle.Support.Case, async: true

  import Kuddle.V2.Utils
  import Kuddle.Tokens

  describe "split_up_to_newline/2" do
    test "can split a string up to a newline" do
      meta = r_token_meta()

      assert {:ok, "a", "\nb", _meta} = split_up_to_newline("a\nb", meta)
      assert {:ok, "a", "\rb", _meta} = split_up_to_newline("a\rb", meta)
      assert {:ok, "a", "\r\nb", _meta} = split_up_to_newline("a\r\nb", meta)
    end
  end

  describe "parse_float_string/1" do
    test "can parse a simple float" do
      assert {:ok, "1.0"} == parse_float_string("1.0")
      assert {:ok, "-1.0"} == parse_float_string("-1.0")
      assert {:ok, "+1.0"} == parse_float_string("+1.0")
    end

    test "can parse a simple float with exponents" do
      assert {:ok, "1.23E100"} == parse_float_string("1.23e100")
      assert {:ok, "-1.23E100"} == parse_float_string("-1.23e100")
      assert {:ok, "+1.23E100"} == parse_float_string("+1.23e100")

      assert {:ok, "1.23E+100"} == parse_float_string("1.23e+100")
      assert {:ok, "-1.23E+100"} == parse_float_string("-1.23e+100")
      assert {:ok, "+1.23E+100"} == parse_float_string("+1.23e+100")

      assert {:ok, "1.23E-100"} == parse_float_string("1.23e-100")
      assert {:ok, "-1.23E-100"} == parse_float_string("-1.23e-100")
      assert {:ok, "+1.23E-100"} == parse_float_string("+1.23e-100")
    end

    test "can parse a simple float with exponents, but no fraction" do
      assert {:ok, "123E100"} == parse_float_string("123e100")
      assert {:ok, "-123E100"} == parse_float_string("-123e100")
      assert {:ok, "+123E100"} == parse_float_string("+123e100")

      assert {:ok, "123E+100"} == parse_float_string("123e+100")
      assert {:ok, "-123E+100"} == parse_float_string("-123e+100")
      assert {:ok, "+123E+100"} == parse_float_string("+123e+100")

      assert {:ok, "123E-100"} == parse_float_string("123e-100")
      assert {:ok, "-123E-100"} == parse_float_string("-123e-100")
      assert {:ok, "+123E-100"} == parse_float_string("+123e-100")
    end
  end
end

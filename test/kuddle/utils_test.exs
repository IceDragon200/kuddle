defmodule Kuddle.UtilsTest do
  use ExUnit.Case, async: true

  import Kuddle.Utils

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

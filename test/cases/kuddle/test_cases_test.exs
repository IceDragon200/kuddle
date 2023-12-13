defmodule Kuddle.TestCasesTest do
  use ExUnit.Case, async: true

  for filename <- Path.wildcard(Path.join(__DIR__, "../fixtures/test_cases/input/*.kdl")) do
    basename = Path.basename(filename)
    expected_filename = Path.expand(Path.join(["../fixtures/test_cases/expected_kdl", basename]), __DIR__)

    describe "test-case #{basename}" do
      @describetag test_case: Path.basename(basename, ".kdl")

      test "encode/decode" do
        assert {:ok, source_blob} = File.read(unquote(filename))
        case File.read(unquote(expected_filename)) do
          {:ok, expected_blob} ->
            assert {:ok, doc, []} = Kuddle.decode(source_blob)
            assert {:ok, expected_blob} == Kuddle.encode(doc)

          {:error, :enoent} ->
            assert {:error, _} = Kuddle.decode(source_blob)
        end
      end
    end
  end
end

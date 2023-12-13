defmodule Kuddle.V1.TestCasesTest do
  use Kuddle.Support.Case, async: true

  for filename <- Path.wildcard(fixture_path("v1/test_cases/input/*.kdl")) do
    basename = Path.basename(filename)
    expected_filename = Path.join([fixture_path("v1/test_cases/output"), basename])

    describe "kdl-v1-case #{basename}" do
      @describetag test_case: Path.basename(basename, ".kdl")

      test "encode/decode" do
        assert {:ok, source_blob} = File.read(unquote(filename))
        case File.read(unquote(expected_filename)) do
          {:ok, expected_blob} ->
            assert {:ok, doc, []} = Kuddle.V1.decode(source_blob)
            assert {:ok, expected_blob} == Kuddle.V1.encode(doc)

          {:error, :enoent} ->
            assert {:error, _} = Kuddle.V1.decode(source_blob)
        end
      end
    end
  end
end

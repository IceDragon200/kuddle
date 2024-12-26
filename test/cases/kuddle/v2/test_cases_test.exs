defmodule Kuddle.V2.TestCasesTest do
  use Kuddle.Support.Case, async: true

  for filename <- Enum.sort(Path.wildcard(fixture_path("v2/test_cases/input/*.kdl"))) do
    basename = Path.basename(filename)
    expected_filename = Path.join([fixture_path("v2/test_cases/output"), basename])

    describe "kdl-v2-case #{basename}" do
      @describetag test_case: Path.basename(basename, ".kdl")

      test "encode/decode" do
        run_test_files(unquote(filename), unquote(expected_filename))
      end
    end
  end

  defp run_test_files(source_filename, expected_filename) do
    assert {:ok, source_blob} = File.read(source_filename)
    case File.read(expected_filename) do
      {:ok, expected_blob} ->
        assert {:ok, doc, []} = Kuddle.V2.decode(source_blob)
        assert {:ok, actual_blob} = Kuddle.V2.encode(doc, integer_format: :dec)
        assert String.trim(expected_blob) == String.trim(actual_blob)

      {:error, :enoent} ->
        assert {:error, _} = Kuddle.V2.decode(source_blob)
    end
  end
end

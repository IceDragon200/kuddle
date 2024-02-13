defmodule Kuddle.Support.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Kuddle.Support.Case
    end
  end

  def fixture_path do
    Path.expand(Path.join(__DIR__, "../fixtures"))
  end

  def fixture_path(path) do
    Path.join(fixture_path(), path)
  end
end

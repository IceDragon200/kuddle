defmodule Kuddle.DecodeError do
  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}) do
    "Could not decode KDL document: #{inspect reason}"
  end
end

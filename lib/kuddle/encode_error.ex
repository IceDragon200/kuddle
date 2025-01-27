defmodule Kuddle.EncodeError do
  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}) do
    "Could not encode KDL document: #{inspect reason}"
  end
end

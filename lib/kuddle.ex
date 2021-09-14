defmodule Kuddle do
  defdelegate decode(blob), to: Kuddle.Decoder
  defdelegate encode(doc), to: Kuddle.Encoder
end

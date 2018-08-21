defmodule TickerBase.Tick do
  @moduledoc false

  defstruct symbol: :symbol, price: 1.0, timestamp: DateTime.to_unix(DateTime.utc_now())

  @type t :: %TickerBase.Tick{symbol: atom, price: float, timestamp: pos_integer}

end

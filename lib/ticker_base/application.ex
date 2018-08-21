defmodule TickerBase.Application do
  @moduledoc false

  import Supervisor.Spec

  use Application

  def start(_type, _args) do
    aliases_map = Application.get_env(:ticker_base, :supported_symbol_aliases)
    children = [
      worker(TickerBase.Database,   [Map.values(aliases_map)], restart: :permanent, shutdown: 5000),
      worker(TickerBase.HttpServer, [aliases_map], restart: :permanent, shutdown: 5000)
    ]

    opts = [strategy: :one_for_one, name: TickerBase.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

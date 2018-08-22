defmodule HttpServerTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias TickerBase.{HttpServer, Tick}

  @aliases_map    %{"EURUSD" => :EURUSD, "BTCUSD" => :BTCUSD}
  @timestamp_from "1534933608453"
  @timestamp_to   "1534935608453"
  @price          "1.5"

  setup_all do
    ExMeck.new(TickerBase.Database)

    ExMeck.expect(TickerBase.Database, :insert_tick!,                 fn _ -> true end)
    ExMeck.expect(TickerBase.Database, :get_all_ticks,                fn _ -> [] end)
    ExMeck.expect(TickerBase.Database, :get_ticks_from_time_range,    fn _, _, _ -> [] end)
    ExMeck.expect(TickerBase.Database, :get_ticks_from_current_month, fn _ -> [] end)

    ExMeck.new(Raxx)

    ExMeck.expect(Raxx, :fetch_query, fn %{query: :time_from_to}  -> {:ok, %{"timestamp_from" => @timestamp_from, "timestamp_to" => @timestamp_to}};
                                         %{query: :data}          -> {:ok, %{"symbol" => "EURUSD", "price" => @price, "timestamp" => @timestamp_from}};
                                         _                        -> {:ok, %{}} end)

    ExMeck.expect(Raxx, :request,     fn _, _ -> %{query: :data} end)
    ExMeck.expect(Raxx, :response,    fn _ -> %{} end)
    ExMeck.expect(Raxx, :set_header,  fn _, _ , _ -> %{} end)
    ExMeck.expect(Raxx, :set_body,    fn _, _ -> %{} end)

    on_exit(fn ->
      ExMeck.unload()
    end)
    :ok
  end
  setup do
    ExMeck.reset(TickerBase.Database)
  end

  test "HttpServer handle correct GET - all ticks" do
    HttpServer.handle_request(%Raxx.Request{method: :GET, path: ["api", "ticks", "EURUSD"]}, @aliases_map)
    assert(ExMeck.contains?(TickerBase.Database, {:_, {TickerBase.Database, :get_all_ticks, [:EURUSD]}, :_}))
  end

  test "HttpServer handle correct GET - timestamp from to" do
    HttpServer.handle_request(%Raxx.Request{method: :GET, path: ["api", "ticks", "EURUSD"], query: :time_from_to}, @aliases_map)
    assert(ExMeck.contains?(TickerBase.Database, {:_, {TickerBase.Database, :get_ticks_from_time_range, [:EURUSD, String.to_integer(@timestamp_from), String.to_integer(@timestamp_to)]}, :_}))
  end

  test "HttpServer handle correct GET - candles" do
    HttpServer.handle_request(%Raxx.Request{method: :GET, path: ["api", "candles", "EURUSD"]}, @aliases_map)
    assert(ExMeck.contains?(TickerBase.Database, {:_, {TickerBase.Database, :get_ticks_from_current_month, [:EURUSD]}, :_}))
  end

  test "HttpServer handle incorrect GET - wrong path" do
    HttpServer.handle_request(%Raxx.Request{method: :GET, path: ["api", "ticks", "EURUSD", "AAA"]}, @aliases_map)
    refute(ExMeck.contains?(TickerBase.Database, {:_, {TickerBase.Database, :get_all_ticks, [:_]}, :_}))
  end

  test "HttpServer handle correct POST - insert data" do
    HttpServer.handle_request(%Raxx.Request{method: :POST, path: ["api", "ticks"], body: "data"}, @aliases_map)
    assert(ExMeck.contains?(TickerBase.Database, {:_, {TickerBase.Database, :insert_tick!, [%Tick{symbol: :EURUSD, price: String.to_float(@price), timestamp: String.to_integer(@timestamp_from)}]}, :_}))
  end

  test "HttpServer handle incorrect POST - wrong path" do
    HttpServer.handle_request(%Raxx.Request{method: :POST, path: ["api", "ticks", "AAA"]}, @aliases_map)
    refute(ExMeck.contains?(TickerBase.Database, {:_, {TickerBase.Database, :insert_tick!, [:_]}, :_}))
  end

end

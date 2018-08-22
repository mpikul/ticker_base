defmodule TickerBase.HttpServer do
  @moduledoc false

  use Ace.HTTP.Service, [port: 8080, cleartext: true]

  alias TickerBase.{Database, Tick}

  require Logger

  @impl Raxx.Server
  def handle_request(%{method: :GET, path: ["api", "ticks", symbol_alias]} = request, aliases_map) do
    Logger.info("Got Request: #{inspect request}}")
    results = aliases_map |> Map.get(symbol_alias) |> get_data(fetch_query(request))
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body(JSON.encode!(results))
  end

  def handle_request(%{method: :GET, path: ["api", "candles", symbol_alias]} = request, aliases_map) do
    Logger.info("Got Request: #{inspect request}}")
    results = aliases_map |> Map.get(symbol_alias) |> get_candles()
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body(JSON.encode!(results))
  end

  def handle_request(%{method: :POST, path: ["api", "ticks"], body: body} = request, aliases_map) do
    Logger.info("Got Request: #{inspect request}}")
    request(:GET, "/?" <> body)
    |> fetch_query()
    |> insert_data(aliases_map)

    response(:ok)
    |> set_header("content-type", "text/plain")
  end

  def handle_request(request, _) do
    Logger.info("Got Request: #{inspect request}}")
    400
    |> response()
    |> set_header("content-type", "text/plain")
  end

  defp insert_data({:ok, %{"symbol" => symbol_alias, "price" => price, "timestamp" => timestamp}}, aliases_map) do
    Database.insert_tick!(%Tick{
      symbol: Map.get(aliases_map, symbol_alias),
      price: string_to_float(price),
      timestamp: String.to_integer(timestamp)}
    )
  end
  defp get_data(symbol, {:ok, %{"timestamp_from" => timestamp_from, "timestamp_to" => timestamp_to}}) do
    symbol
    |> Database.get_ticks_from_time_range(String.to_integer(timestamp_from), String.to_integer(timestamp_to))
    |> Enum.map(fn tick -> convert_data_to_result(tick) end)
  end

  defp get_data(symbol, {:ok, _params}) do
    symbol
    |> Database.get_all_ticks()
    |> Enum.map(fn tick -> convert_data_to_result(tick) end)
  end

  defp get_candles(symbol) do
    symbol
    |> Database.get_ticks_from_current_month()
    |> get_daily_stats_from_ticks()
    |> Enum.map(fn data -> convert_data_to_result(data) end)
  end

  def get_daily_stats_from_ticks(ticks) do
    ticks
    |> Enum.group_by(fn %Tick{timestamp: timestamp} -> get_day_of_month(timestamp) end)
    |> Enum.map(fn {day, ticks_in_day} -> {day, get_min_max_avg_from_ticks(ticks_in_day)} end)
    |> Enum.sort()
  end

  def get_min_max_avg_from_ticks([%Tick{price: first_price}|rest] = ticks) do
    {min, max, sum} = List.foldl(rest, {first_price, first_price, first_price},
      fn %Tick{price: price}, {min, max, sum} ->
        {Enum.min([min, price]),
         Enum.max([max, price]),
         sum + price
        }
      end)

    {min, max, sum / length(ticks)}
  end

  defp get_day_of_month(timestamp) do
    %DateTime{day: day} = DateTime.from_unix!(timestamp, :millisecond)
    day
  end

  defp convert_data_to_result(%Tick{price: price, timestamp: timestamp}) do
    %{price: float_to_string(price), timestamp: timestamp}
  end
  defp convert_data_to_result({day, {min, max, avg}}) do
    date = Date.utc_today()
    [date: Date.to_string(%Date{date | day: day}),
      min_price: float_to_string(min),
      max_price: float_to_string(max),
      avg_price: float_to_string(avg)]
  end

  defp float_to_string(number), do: :erlang.float_to_binary(number, [{:decimals, 4}])
  defp string_to_float(number) do
    {float_number, _} = Float.parse(number)
    float_number
  end
end

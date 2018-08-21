defmodule TickerBase.HttpServer do
  @moduledoc false

  use Ace.HTTP.Service, [port: 8080, cleartext: true]

  alias TickerBase.{Tick, Database}

  @impl Raxx.Server
  def handle_request(request = %{method: :GET, path: ["api", "ticks", symbol]}, aliases_map) do
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body(Poison.encode!(get_data(Map.get(aliases_map, symbol), fetch_query(request))))
  end

  def handle_request(%{method: :GET, path: ["api", "candles", symbol]}, aliases_map) do
    response(:ok)
    |> set_header("content-type", "text/plain")
    |> set_body(Poison.encode!(get_candles(Map.get(aliases_map, symbol))))
  end

  def handle_request(%{method: :POST, path: ["api", "ticks"], body: body}, aliases_map) do
    request(:GET, "/?" <> body)
    |> fetch_query()
    |> insert_data(aliases_map)

    response(:ok)
    |> set_header("content-type", "text/plain")
  end

  defp insert_data({:ok ,%{"symbol" => symbol, "price" => price, "timestamp" => timestamp}}, aliases_map) do
    Database.insert_tick!(%Tick{
      symbol: Map.get(aliases_map, symbol),
      price: String.to_float(price),
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
  defp get_data(_, _) do
    []
  end

  defp get_candles(symbol) do
    symbol
    |> Database.get_ticks_from_current_month()
    |> get_daily_stats_from_ticks()
    |> Enum.map(fn data -> convert_data_to_result(data) end)
  end

  def get_daily_stats_from_ticks([]), do: []
  def get_daily_stats_from_ticks(ticks) do
    ticks
    |> Enum.group_by(fn %Tick{timestamp: timestamp} -> get_day_of_month(timestamp) end)
    |> Enum.map(fn {day, ticks_in_day} -> {day, get_min_max_avg_from_ticks(ticks_in_day)} end)
    |> Enum.sort()
  end

  def get_min_max_avg_from_ticks(ticks) do
    {min, max} = Enum.min_max_by(ticks, fn %Tick{price: price} -> price end)
    sum = List.foldl(ticks, 0.0, fn %Tick{price: price}, acc -> acc + price end)

    {min, max, sum / length(ticks)}
  end

  defp get_day_of_month(timestamp) do
    %DateTime{day: day} = DateTime.from_unix!(timestamp)
    day
  end

  defp convert_data_to_result(%Tick{price: price, timestamp: timestamp}) do
    %{price: :erlang.float_to_binary(price, [{:decimals, 4}]), timestamp: timestamp}
  end
  defp convert_data_to_result({day, {%Tick{price: min}, %Tick{price: max}, avg}}) do
    date = Date.utc_today()
    %{date: Date.to_string(%Date{date | day: day}),
      min_price: :erlang.float_to_binary(min, [{:decimals, 4}]),
      max_price: :erlang.float_to_binary(max, [{:decimals, 4}]),
      avg_price: :erlang.float_to_binary(avg, [{:decimals, 4}])}
  end
end
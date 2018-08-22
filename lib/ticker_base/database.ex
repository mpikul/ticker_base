defmodule TickerBase.Database do
  @moduledoc false
  
  use GenServer

  alias TickerBase.Tick

  @spec start_link(list(atom())) :: GenServer.on_start
  def start_link(symbols) do
    GenServer.start_link(__MODULE__, symbols, name: __MODULE__)
  end

  @spec insert_tick!(Tick.t()) :: true
  def insert_tick!(%Tick{symbol: symbol, price: price, timestamp: timestamp}) when is_atom(symbol) and is_float(price) do
    :ets.insert(symbol, {timestamp, price})
  end

  @spec get_all_ticks(atom()) :: list(Tick.t())
  def get_all_ticks(symbol) do
    symbol |> :ets.tab2list() |> Enum.map(fn {timestamp, price} -> %Tick{symbol: symbol, price: price, timestamp: timestamp} end)
  end

  @spec get_ticks_from_time_range(atom(), pos_integer(), pos_integer()) :: list(Tick.t())
  def get_ticks_from_time_range(symbol, timestamp_from, timestamp_to) do
    :ets.safe_fixtable(symbol, true)
    records = get_records(symbol, timestamp_from, timestamp_to, [])
    :ets.safe_fixtable(symbol, false)
    records
  end

  @spec get_ticks_from_current_month(atom()) :: list(Tick.t())
  def get_ticks_from_current_month(symbol) do
    date_now          = %DateTime{year: year, month: month} = DateTime.utc_now()
    last_day_of_month = :calendar.last_day_of_the_month(year, month)
    timestamp_from    = DateTime.to_unix(%DateTime{date_now | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0,0}}, :millisecond)
    timestamp_to      = DateTime.to_unix(%DateTime{date_now | day: last_day_of_month, hour: 23, minute: 59, second: 59, microsecond: {999_999,6}}, :millisecond)

    :ets.safe_fixtable(symbol, true)
    records = get_records(symbol, timestamp_from, timestamp_to, [])
    :ets.safe_fixtable(symbol, false)
    records
  end

  def init(symbols) do
    symbols
    |> Enum.dedup()
    |> Enum.each(fn symbol -> :ets.new(symbol, [:ordered_set, :public, :named_table]) end)

    {:ok, %{}}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp get_records(_, :"$end_of_table", _, records) do
    Enum.reverse(records)
  end
  defp get_records(_, current_timestamp, last_timestamp, records) when last_timestamp < current_timestamp do
    Enum.reverse(records)
  end
  defp get_records(symbol, current_timestamp, last_timestamp, records) do
    get_records(symbol, :ets.next(symbol, current_timestamp), last_timestamp, get_single_record(symbol, :ets.lookup(symbol, current_timestamp), records))
  end

  defp get_single_record(symbol, [{current_timestamp, price}], records) do
    [%Tick{symbol: symbol, price: price, timestamp: current_timestamp}|records]
  end
  defp get_single_record(_, _, records), do: records

end

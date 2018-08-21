defmodule DatabaseTest do
  @moduledoc false

  use ExUnit.Case, async: false

  alias TickerBase.{Tick, Database}

  setup do
    {:ok, pid} = start_supervised(%{id: Database,start: {TickerBase.Database, :start_link, [[:EURUSD, :BTCUSD]]}}, restart: :temporary)
    %{pid: pid}
  end

  test "Database Started", %{pid: pid} do
    assert(Process.alive?(pid))
  end

  test "Empty Database after start" do
    assert([] == Database.get_all_ticks(:EURUSD))
    assert([] == Database.get_all_ticks(:BTCUSD))
    assert_raise(ArgumentError, fn -> Database.get_all_ticks(:UNSUPPORTED_SYMBOL) end)
  end

  test "Insert first tick" do
    tick_to_insert1 = %Tick{symbol: :EURUSD, price: 1.5}
    tick_to_insert2 = %Tick{symbol: :BTCUSD, price: 2.1}

    assert(Database.insert_tick!(tick_to_insert1))
    assert([tick_to_insert1] == Database.get_all_ticks(:EURUSD))
    assert([] == Database.get_all_ticks(:BTCUSD))
    assert_raise(ArgumentError, fn -> Database.get_all_ticks(:UNSUPPORTED_SYMBOL) end)

    assert(Database.insert_tick!(tick_to_insert2))

    assert([tick_to_insert1] == Database.get_all_ticks(:EURUSD))
    assert([tick_to_insert2] == Database.get_all_ticks(:BTCUSD))
    assert_raise(ArgumentError, fn -> Database.get_all_ticks(:UNSUPPORTED_SYMBOL) end)
  end

  test "Insert incorrect tick" do
    assert_raise(ArgumentError, fn -> Database.insert_tick!(%Tick{symbol: :UNSUPPORTED_SYMBOL}) end)
  end

  test "Ticks from incorrect time range" do
    for n <- 10..100, do: assert(Database.insert_tick!(%Tick{symbol: :EURUSD, timestamp: n}))

    assert([] == Database.get_ticks_from_time_range(:EURUSD, 60, 30))
    assert([] == Database.get_ticks_from_time_range(:EURUSD, 120, 123))
    assert([] == Database.get_ticks_from_time_range(:EURUSD, 1, 5))
    assert([] == Database.get_ticks_from_time_range(:EURUSD, 1, 9))
  end

  test "Ticks from time range" do
    for n <- 1..100, do: assert(Database.insert_tick!(%Tick{symbol: :EURUSD, timestamp: n}))

    for x <- 1..100, y <- x..100, do: test_ticks_from_time_range(:EURUSD, x, y)
  end

  test "Time range without any ticks" do
    for n <- 1..10, do: assert(Database.insert_tick!(%Tick{symbol: :EURUSD, timestamp: n * 10}))

    for x <- 0..9, y <- x * 10 + 1..x * 10 + 9, do: assert([] == Database.get_ticks_from_time_range(:EURUSD, x * 10 + 1, y))
  end

  test "No ticks from current month" do
    for n <- 1..10, do: assert(Database.insert_tick!(%Tick{symbol: :EURUSD, timestamp: n}))

    assert([] == Database.get_ticks_from_current_month(:EURUSD))
  end

  test "One tick from current month" do
    for n <- 1..1000, do: assert(Database.insert_tick!(%Tick{symbol: :EURUSD, timestamp: n}))

    tick_to_insert = %Tick{symbol: :EURUSD, price: 1.5}

    assert(Database.insert_tick!(tick_to_insert))
    assert([tick_to_insert] == Database.get_ticks_from_current_month(:EURUSD))
  end

  test "Parallel inserts" do
    tasks = for n <- 1..5000, do: Task.async(fn -> t = n * 1000; insert_multiple_ticks(t, t + 99) end)
    Enum.each(tasks, fn task -> assert(Task.await(task)) end)

    assert(500000 == length(Database.get_all_ticks(:EURUSD)))
  end

  defp test_ticks_from_time_range(symbol, time_from, time_to) do
    result = Enum.map(time_from..time_to, fn n -> %Tick{symbol: symbol, timestamp: n} end)

    assert(result == Database.get_ticks_from_time_range(:EURUSD, time_from, time_to))
  end

  defp insert_multiple_ticks(timestamp_from, timestamp_to) when timestamp_to < timestamp_from do
    true
  end
  defp insert_multiple_ticks(timestamp_from, timestamp_to) do
    assert(Database.insert_tick!(%Tick{symbol: :EURUSD, timestamp: timestamp_from}))
    insert_multiple_ticks(timestamp_from + 1, timestamp_to)
  end

end

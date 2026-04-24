defmodule StockApp.StockSimulator do
  @moduledoc """
  GenServer that simulates stock price changes at a configurable interval.

  Maintains a pool of stocks with realistic base prices, applies random-walk
  price updates on each tick, and broadcasts a summary to all subscribed
  screen processes.

  The update interval, number of stocks, and persistence toggle can be changed
  at runtime. When persistence is enabled, every tick writes one row per stock
  to the `stock_prices` SQLite table via Ecto.
  """

  use GenServer

  @stock_pool (for i <- 1..1000 do
    symbol = "STK" <> String.pad_leading(Integer.to_string(i), 3, "0")
    name = "Stock Corp #{i}"
    base_price = Float.round(10 + :math.sin(i * 0.1) * 200 + 200, 2)
    {symbol, name, base_price}
  end)

  @default_interval    2_000
  @default_stock_count 10
  @default_persist     false
  @history_max         1_000

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Subscribe the calling process to stock updates. Sends {:stock_update, summary}."
  def subscribe do
    GenServer.call(__MODULE__, :subscribe)
  end

  @doc "Unsubscribe the calling process from stock updates."
  def unsubscribe do
    GenServer.call(__MODULE__, :unsubscribe)
  end

  @doc "Return the full stocks map (symbol => stock data)."
  def get_stocks do
    GenServer.call(__MODULE__, :get_stocks)
  end

  @doc "Return data for a single stock symbol."
  def get_stock(symbol) do
    GenServer.call(__MODULE__, {:get_stock, symbol})
  end

  @doc "Return the current update interval in milliseconds."
  def get_interval do
    GenServer.call(__MODULE__, :get_interval)
  end

  @doc "Set the update interval in milliseconds. Takes effect on the next tick."
  def set_interval(interval_ms) when is_integer(interval_ms) and interval_ms > 0 do
    GenServer.call(__MODULE__, {:set_interval, interval_ms})
  end

  @doc "Return the current number of stocks being simulated."
  def get_stock_count do
    GenServer.call(__MODULE__, :get_stock_count)
  end

  @doc "Set the number of stocks. Re-initialises the stock pool."
  def set_stock_count(count) when is_integer(count) and count > 0 do
    GenServer.call(__MODULE__, {:set_stock_count, count})
  end

  @doc "Return whether price persistence to SQLite is enabled."
  def get_persist do
    GenServer.call(__MODULE__, :get_persist)
  end

  @doc "Enable or disable price persistence to SQLite."
  def set_persist(persist) when is_boolean(persist) do
    GenServer.call(__MODULE__, {:set_persist, persist})
  end

  @doc "Return the current config (interval, stock count, persist)."
  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  # ---------------------------------------------------------------------------
  # Server callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval    = Keyword.get(opts, :interval, @default_interval)
    stock_count = min(Keyword.get(opts, :stock_count, @default_stock_count), length(@stock_pool))
    persist?    = Keyword.get(opts, :persist, @default_persist)

    stocks    = init_stocks(stock_count)
    timer_ref = schedule_tick(interval)

    state = %{
      stocks:      stocks,
      interval:    interval,
      stock_count: stock_count,
      persist?:    persist?,
      timer_ref:   timer_ref,
      subscribers: MapSet.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:subscribe, {pid, _}, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  def handle_call(:unsubscribe, {pid, _}, state) do
    {:reply, :ok, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  def handle_call(:get_stocks, _from, state) do
    {:reply, state.stocks, state}
  end

  def handle_call({:get_stock, symbol}, _from, state) do
    {:reply, Map.get(state.stocks, symbol), state}
  end

  def handle_call(:get_interval, _from, state) do
    {:reply, state.interval, state}
  end

  def handle_call({:set_interval, interval_ms}, _from, state) do
    Process.cancel_timer(state.timer_ref)
    timer_ref = schedule_tick(interval_ms)
    {:reply, :ok, %{state | interval: interval_ms, timer_ref: timer_ref}}
  end

  def handle_call(:get_stock_count, _from, state) do
    {:reply, state.stock_count, state}
  end

  def handle_call({:set_stock_count, count}, _from, state) do
    count = min(count, length(@stock_pool))
    stocks = init_stocks(count)
    {:reply, :ok, %{state | stocks: stocks, stock_count: count}}
  end

  def handle_call(:get_persist, _from, state) do
    {:reply, state.persist?, state}
  end

  def handle_call({:set_persist, persist?}, _from, state) do
    {:reply, :ok, %{state | persist?: persist?}}
  end

  def handle_call(:get_config, _from, state) do
    {:reply, %{interval: state.interval, stock_count: state.stock_count, persist: state.persist?}, state}
  end

  @impl true
  def handle_info(:tick, state) do
    stocks    = update_prices(state.stocks)
    broadcast(stocks, state.subscribers)

    if state.persist? do
      persist_prices(stocks)
    end

    timer_ref = schedule_tick(state.interval)
    {:noreply, %{state | stocks: stocks, timer_ref: timer_ref}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end

  defp init_stocks(count) do
    @stock_pool
    |> Enum.take(count)
    |> Enum.map(fn {symbol, name, base_price} ->
      # Small initial jitter so prices aren't exactly the base
      price  = Float.round(base_price * (1 + (:rand.uniform() - 0.5) * 0.02), 2)
      change = Float.round(price - base_price, 2)
      pct    = Float.round(change / base_price * 100, 2)

      {symbol, %{
        symbol:         symbol,
        name:           name,
        price:          price,
        previous_close: base_price,
        open:           price,
        high:           price,
        low:            price,
        change:         change,
        change_percent: pct,
        history:        [price]
      }}
    end)
    |> Map.new()
  end

  defp update_prices(stocks) do
    Map.new(stocks, fn {symbol, stock} ->
      # Random walk: ±1.5 % max per tick
      delta     = (:rand.uniform() - 0.5) * 0.03
      new_price = max(Float.round(stock.price * (1 + delta), 2), 0.01)

      change = Float.round(new_price - stock.previous_close, 2)
      pct    = Float.round(change / stock.previous_close * 100, 2)

      history = [new_price | stock.history] |> Enum.take(@history_max)

      {symbol, %{stock |
        price:          new_price,
        change:         change,
        change_percent: pct,
        high:           max(stock.high, new_price),
        low:            min(stock.low, new_price),
        history:        history
      }}
    end)
  end

  defp persist_prices(stocks) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    entries =
      stocks
      |> Map.values()
      |> Enum.map(fn stock ->
        %{
          symbol:         stock.symbol,
          name:           stock.name,
          price:          stock.price,
          previous_close: stock.previous_close,
          open:           stock.open,
          high:           stock.high,
          low:            stock.low,
          change:         stock.change,
          change_percent: stock.change_percent,
          inserted_at:    now,
          updated_at:     now
        }
      end)

    try do
      StockApp.Repo.insert_all(StockApp.StockPrice, entries)
    rescue
      _ -> :ok
    end
  end

  defp broadcast(stocks, subscribers) do
    summary = build_summary(stocks)
    Enum.each(subscribers, fn pid ->
      send(pid, {:stock_update, summary})
    end)
  end

  defp build_summary(stocks) do
    stocks_list =
      stocks
      |> Map.values()
      |> Enum.sort_by(& &1.symbol)

    total = Enum.reduce(stocks_list, 0.0, fn s, acc -> acc + s.change_percent end)
    avg   = if stocks_list == [], do: 0.0, else: Float.round(total / length(stocks_list), 2)

    %{
      stocks:         stocks_list,
      average_change: avg,
      gainers:        Enum.count(stocks_list, &(&1.change > 0)),
      losers:         Enum.count(stocks_list, &(&1.change < 0)),
      timestamp:      System.system_time(:millisecond)
    }
  end
end

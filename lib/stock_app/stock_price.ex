defmodule StockApp.StockPrice do
  @moduledoc """
  Ecto schema for persisting stock price snapshots.

  Each row represents a single price tick for a stock symbol,
  recorded when persistence is enabled in the simulator.
  """
  use Ecto.Schema

  schema "stock_prices" do
    field :symbol,          :string
    field :name,            :string
    field :price,           :float
    field :change,          :float
    field :change_percent,  :float
    field :high,            :float
    field :low,             :float
    field :open,            :float
    field :previous_close,  :float
    timestamps()
  end
end

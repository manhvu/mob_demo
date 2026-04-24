defmodule StockApp.Repo.Migrations.CreateStockPrices do
  use Ecto.Migration

  def change do
    create table(:stock_prices) do
      add :symbol,         :string, null: false
      add :name,           :string, null: false
      add :price,          :float,  null: false
      add :previous_close, :float,  null: false
      add :open,           :float,  null: false
      add :high,           :float,  null: false
      add :low,            :float,  null: false
      add :change,         :float,  null: false
      add :change_percent, :float,  null: false
      timestamps()
    end

    create index(:stock_prices, [:symbol])
    create index(:stock_prices, [:inserted_at])
  end
end

defmodule StockApp.HomeScreen do
  @moduledoc """
  Main screen showing all stocks with a summary bar (average change,
  gainers / losers) and a tappable list of stock rows. Subscribes to
  StockSimulator so prices update in real time.
  """
  use Mob.Screen

  # ── Mount ─────────────────────────────────────────────────────────────────────

  def mount(_params, _session, socket) do
    StockApp.StockSimulator.subscribe()

    stocks = StockApp.StockSimulator.get_stocks() |> Map.values() |> Enum.sort_by(& &1.symbol)

    socket =
      socket
      |> Mob.Socket.assign(:stocks, stocks)
      |> Mob.Socket.assign(:average_change, 0.0)
      |> Mob.Socket.assign(:gainers, 0)
      |> Mob.Socket.assign(:losers, 0)

    {:ok, socket}
  end

  # ── Render ────────────────────────────────────────────────────────────────────

  def render(assigns) do
    {avg_color, avg_arrow} = change_style(assigns.average_change)

    stock_rows =
      Enum.map(assigns.stocks, fn stock ->
        {row_color, arrow} = change_style(stock.change)

        %{
          type: :row,
          props: %{
            fill_width: true,
            background: :surface,
            padding_left: :space_md,
            padding_right: :space_md,
            padding_top: 14,
            padding_bottom: 14,
            on_tap: {self(), {:open_stock, stock.symbol}}
          },
          children: [
            %{
              type: :button,
              props: %{
                text: "📖",
                background: :surface_raised,
                text_color: :on_surface,
                text_size: :sm,
                padding: :space_sx,
                fill_width: false,
                on_tap: {self(), {:open_stock, stock.symbol}}
              },
              children: []
            },
            %{
              type: :spacer,
              props: %{},
              children: []
              },
            # Symbol + Name
            %{
              type: :column,
              props: %{weight: 1},
              children: [
                %{
                  type: :text,
                  props: %{
                    text: stock.symbol,
                    text_size: :base,
                    text_color: :on_surface,
                    font_weight: "bold",
                    padding: 0,
                    on_tap: {self(), {:open_stock, stock.symbol}}
                  },
                  children: []
                },
                %{
                  type: :text,
                  props: %{
                    text: stock.name,
                    text_size: :xs,
                    text_color: :muted,
                    padding: 0
                  },
                  children: []
                }
              ]
            },
            # Price + Change
            %{
              type: :column,
              props: %{
                align: :end,
                on_tap: {self(), {:open_stock, stock.symbol}}},
              children: [
                %{
                  type: :text,
                  props: %{
                    text: format_price(stock.price),
                    text_size: :base,
                    text_color: :on_surface,
                    font_weight: "medium",
                    padding: 0
                  },
                  children: []
                },
                %{
                  type: :row,
                  props: %{gap: 4, align: :center},
                  children: [
                    %{
                      type: :text,
                      props: %{text: arrow, text_size: :xs, text_color: row_color},
                      children: []
                    },
                    %{
                      type: :text,
                      props: %{
                        text: "#{format_change(stock.change)} (#{format_pct(stock.change_percent)})",
                        text_size: :xs,
                        text_color: row_color,
                        padding: 0
                      },
                      children: []
                    }
                  ]
                }
              ]
            }
          ]
        }
      end)

    column_children =
      [
        # ── Header ────────────────────────────────────────────────────────
        %{
          type: :text,
          props: %{
            text: "📈  Stock Simulator - #{length(assigns.stocks)} items",
            text_size: :xl,
            text_color: :on_primary,
            background: :primary,
            padding: :space_md,
            fill_width: true
          },
          children: []
        },

        # ── Summary bar ──────────────────────────────────────────────────
        %{
          type: :row,
          props: %{fill_width: true, background: :surface_raised, padding: :space_md, gap: 8},
          children: [
            summary_cell(avg_arrow <> " Avg", format_pct(assigns.average_change), avg_color),
            summary_cell("▲ Gainers", "#{assigns.gainers}", :green_400),
            summary_cell("▼ Losers", "#{assigns.losers}", :red_400)
          ]
        },

        %{type: :divider, props: %{color: :border}, children: []},

        # ── Stock list heading ────────────────────────────────────────────
        %{
          type: :row,
          props: %{fill_width: true, padding_left: :space_md, padding_right: :space_md, padding_top: :space_sm, padding_bottom: :space_xs},
          children: [
            %{
              type: :text,
              props: %{text: "Stock", text_size: :xs, text_color: :muted, font_weight: "medium"},
              children: []
            },
            %{
              type: :spacer,
              props: %{},
              children: []
            },
            %{
              type: :text,
              props: %{text: "Price / Change", text_size: :xs, text_color: :muted, font_weight: "medium"},
              children: []
            }
          ]
        },

        %{type: :divider, props: %{color: :border}, children: []}
      ] ++ stock_rows ++ [
        %{type: :spacer, props: %{size: 24}, children: []},

        # ── Config button ─────────────────────────────────────────────────
        %{
          type: :button,
          props: %{
            text: "⚙️  Configure",
            background: :surface_raised,
            text_color: :on_surface,
            text_size: :base,
            padding: :space_md,
            fill_width: true,
            on_tap: {self(), :open_config}
          },
          children: []
        },
        %{type: :spacer, props: %{size: 16}, children: []}
      ]

    %{
      type: :scroll,
      props: %{background: :background},
      children: [
        %{
          type: :column,
          props: %{background: :background, fill_width: true},
          children: column_children
        }
      ]
    }
  end

  # ── Events ────────────────────────────────────────────────────────────────────

  def handle_info({:stock_update, summary}, socket) do
    {:noreply,
     socket
     |> Mob.Socket.assign(:stocks, summary.stocks)
     |> Mob.Socket.assign(:average_change, summary.average_change)
     |> Mob.Socket.assign(:gainers, summary.gainers)
     |> Mob.Socket.assign(:losers, summary.losers)}
  end

  def handle_info({:tap, {:open_stock, symbol}}, socket) do
    {:noreply,
     Mob.Socket.push_screen(socket, StockApp.DetailScreen, %{
       symbol: symbol,
       parent_pid: self()
     })}
  end

  def handle_info({:tap, :open_config}, socket) do
    {:noreply, Mob.Socket.push_screen(socket, StockApp.ConfigScreen, %{parent_pid: self()})}
  end

  def handle_info(:config_applied, socket) do
    stocks = StockApp.StockSimulator.get_stocks() |> Map.values() |> Enum.sort_by(& &1.symbol)
    {:noreply, Mob.Socket.assign(socket, :stocks, stocks)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp summary_cell(label, value, color) do
    %{
      type: :column,
      props: %{weight: 1, align: :center, padding: :space_xs},
      children: [
        %{type: :text, props: %{text: value, text_size: :base, text_color: color, font_weight: "bold", text_align: "center"}, children: []},
        %{type: :text, props: %{text: label, text_size: :xs, text_color: :muted, text_align: "center"}, children: []}
      ]
    }
  end

  defp change_style(change) when change > 0, do: {:green_400, "▲"}
  defp change_style(change) when change < 0, do: {:red_400, "▼"}
  defp change_style(_), do: {:muted, "—"}

  defp format_price(price) do
    :erlang.float_to_binary(price / 1, decimals: 2)
  end

  defp format_change(change) do
    sign = if change >= 0, do: "+", else: ""
    sign <> :erlang.float_to_binary(change / 1, decimals: 2)
  end

  defp format_pct(pct) do
    sign = if pct >= 0, do: "+", else: ""
    sign <> :erlang.float_to_binary(pct / 1, decimals: 2) <> "%"
  end
end

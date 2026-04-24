defmodule StockApp.DetailScreen do
  @moduledoc """
  Detail screen for a single stock — shows price, change, high/low/open,
  and a scrolling price history list. Subscribes to StockSimulator updates
  so the UI refreshes in real time.
  """
  use Mob.Screen

  # ── Mount ─────────────────────────────────────────────────────────────────────

  def mount(%{symbol: symbol, parent_pid: parent_pid}, _session, socket) do
    StockApp.StockSimulator.subscribe()

    stock =
      StockApp.StockSimulator.get_stock(symbol) ||
      %{symbol: symbol, name: symbol, price: 0.0, change: 0.0,
        change_percent: 0.0, high: 0.0, low: 0.0, open: 0.0,
        previous_close: 0.0, history: []}

    socket =
      socket
      |> Mob.Socket.assign(:stock, stock)
      |> Mob.Socket.assign(:symbol, symbol)
      |> Mob.Socket.assign(:parent_pid, parent_pid)

    {:ok, socket}
  end

  # ── Render ────────────────────────────────────────────────────────────────────

  def render(assigns) do
    stock = assigns.stock
    {_change_color, arrow} = change_style(stock.change)

    price_history_rows =
      stock.history
      |> Enum.with_index()
      |> Enum.map(fn {price, idx} ->
        prev = Enum.at(stock.history, idx + 1, price)
        {row_color, row_arrow} = change_style(price - prev)

        %{
          type: :row,
          props: %{fill_width: true, padding_left: :space_md, padding_right: :space_md, padding_top: 10, padding_bottom: 10},
          children: [
            %{
              type: :text,
              props: %{text: "Tick #{idx + 1}", text_size: :sm, text_color: :muted, weight: 1},
              children: []
            },
            %{
              type: :row,
              props: %{gap: 4, align: :center},
              children: [
                %{
                  type: :text,
                  props: %{text: row_arrow, text_size: :xs, text_color: row_color},
                  children: []
                },
                %{
                  type: :text,
                  props: %{text: format_price(price), text_size: :sm, text_color: row_color, font_weight: "medium"},
                  children: []
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
          type: :column,
          props: %{background: :primary, padding: :space_lg, fill_width: true},
          children: [
            %{
              type: :row,
              props: %{fill_width: true, align: :center},
              children: [
                %{
                  type: :column,
                  props: %{weight: 1},
                  children: [
                    %{
                      type: :text,
                      props: %{text: stock.name, text_size: :xl, text_color: :on_primary, font_weight: "bold"},
                      children: []
                    },
                    %{
                      type: :text,
                      props: %{text: stock.symbol, text_size: :sm, text_color: :on_primary},
                      children: []
                    }
                  ]
                },
                %{
                  type: :column,
                  props: %{align: :end},
                  children: [
                    %{
                      type: :text,
                      props: %{text: format_price(stock.price), text_size: :"2xl", text_color: :on_primary, font_weight: "bold"},
                      children: []
                    },
                    %{
                      type: :row,
                      props: %{gap: 4, align: :center},
                      children: [
                        %{
                          type: :text,
                          props: %{text: arrow, text_size: :sm, text_color: :on_primary},
                          children: []
                        },
                        %{
                          type: :text,
                          props: %{
                            text: "#{format_change(stock.change)} (#{format_pct(stock.change_percent)})",
                            text_size: :sm,
                            text_color: :on_primary
                          },
                          children: []
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        },

        # ── Key stats ─────────────────────────────────────────────────────
        %{
          type: :row,
          props: %{fill_width: true, background: :surface, padding: :space_md, gap: 8},
          children: [
            stat_cell("Open", format_price(stock.open)),
            stat_cell("High", format_price(stock.high)),
            stat_cell("Low", format_price(stock.low)),
            stat_cell("Prev Close", format_price(stock.previous_close))
          ]
        },

        %{type: :divider, props: %{color: :border}, children: []},

        # ── Price history heading ─────────────────────────────────────────
        %{
          type: :row,
          props: %{fill_width: true, padding_left: :space_md, padding_right: :space_md, padding_top: :space_md, padding_bottom: :space_xs},
          children: [
            %{
              type: :text,
              props: %{text: "Price History", text_size: :base, text_color: :on_surface, font_weight: "bold"},
              children: []
            },
            %{
              type: :spacer,
              props: %{},
              children: []
            },
            %{
              type: :text,
              props: %{text: "#{length(stock.history)} ticks", text_size: :xs, text_color: :muted},
              children: []
            }
          ]
        },

        # ── Price history rows ────────────────────────────────────────────
        %{
          type: :divider,
          props: %{color: :border},
          children: []
        }
      ] ++ price_history_rows ++ [
        %{type: :spacer, props: %{size: 24}, children: []},

        # ── Back button ───────────────────────────────────────────────────
        %{
          type: :button,
          props: %{
            text: "← Back to Stocks",
            background: :surface_raised,
            text_color: :on_surface,
            text_size: :lg,
            padding: :space_md,
            fill_width: true,
            on_tap: {self(), :back}
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
    stock =
      Enum.find(summary.stocks, &(&1.symbol == socket.assigns.symbol)) ||
      socket.assigns.stock

    {:noreply, Mob.Socket.assign(socket, :stock, stock)}
  end

  def handle_info({:tap, :back}, socket) do
    StockApp.StockSimulator.unsubscribe()
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # ── Private helpers ───────────────────────────────────────────────────────────

  defp stat_cell(label, value) do
    %{
      type: :column,
      props: %{weight: 1, align: :center, padding: :space_xs},
      children: [
        %{type: :text, props: %{text: value, text_size: :sm, text_color: :on_surface, font_weight: "medium", text_align: "center"}, children: []},
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

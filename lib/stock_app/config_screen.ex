defmodule StockApp.ConfigScreen do
  @moduledoc "Configuration screen for update interval, number of stocks, and SQLite persistence."
  use Mob.Screen

  @interval_presets [
    {"100ms",  100},
    {"1s",  1_000},
    {"3s",  3_000},
    {"5s", 10_000}
  ]

  @count_presets [10, 30, 50, 100, 900]

  def mount(params, _session, socket) do
    config = StockApp.StockSimulator.get_config()
    socket =
      socket
      |> Mob.Socket.assign(:interval, config.interval)
      |> Mob.Socket.assign(:stock_count, config.stock_count)
      |> Mob.Socket.assign(:persist, config.persist)
      |> Mob.Socket.assign(:saved, false)
      |> Mob.Socket.assign(:parent_pid, Map.get(params, :parent_pid))
    {:ok, socket}
  end

  def render(assigns) do
    interval_label = format_interval(assigns.interval)

    saved_notice =
      if assigns.saved do
        [
          %{type: :spacer, props: %{size: 12}, children: []},
          %{
            type: :box,
            props: %{background: :green_400, padding: :space_sm, corner_radius: :radius_sm},
            children: [
              %{type: :text, props: %{text: "✓ Settings saved", text_size: :sm, text_color: :white, padding: 0}, children: []}
            ]
          }
        ]
      else
        []
      end

    persist_toggle_change = {self(), :persist_toggled}

    %{
      type: :scroll,
      props: %{background: :background},
      children: [
        %{
          type: :column,
          props: %{background: :background, padding: :space_md},
          children: [
            header("⚙️  Configuration"),
            %{type: :spacer, props: %{size: 24}, children: []},

            # ── Update Interval ──────────────────────────────────────────
            %{
              type: :text,
              props: %{text: "Update Interval", text_size: :lg, text_color: :on_surface, font_weight: "bold", padding: 0},
              children: []
            },
            %{
              type: :text,
              props: %{text: "How often stock prices refresh", text_size: :sm, text_color: :muted, padding: 0},
              children: []
            },
            %{type: :spacer, props: %{size: 12}, children: []},

            # Current value display
            %{
              type: :box,
              props: %{background: :surface_raised, padding: :space_md, corner_radius: :radius_md, fill_width: true},
              children: [
                %{
                  type: :text,
                  props: %{
                    text: interval_label,
                    text_size: :"2xl",
                    text_color: :primary,
                    font_weight: "bold",
                    text_align: "center",
                    padding: 0
                  },
                  children: []
                }
              ]
            },
            %{type: :spacer, props: %{size: 12}, children: []},

            # Interval preset buttons
            %{
              type: :row,
              props: %{fill_width: true, gap: 1},
              children: Enum.map(@interval_presets, fn {label, ms} ->
                active = assigns.interval == ms
                %{
                  type: :button,
                  props: %{
                    text: label,
                    weight: 1,
                    background: if(active, do: :primary, else: :surface),
                    text_color: if(active, do: :on_primary, else: :on_surface),
                    text_size: :base,
                    padding: :space_sx,
                    on_tap: {self(), {:set_interval, ms}}
                  },
                  children: []
                }
              end)
            },

            %{type: :spacer, props: %{size: 32}, children: []},
            %{type: :divider, props: %{color: :border}, children: []},
            %{type: :spacer, props: %{size: 24}, children: []},

            # ── Number of Stocks ─────────────────────────────────────────
            %{
              type: :text,
              props: %{text: "Number of Stocks", text_size: :lg, text_color: :on_surface, font_weight: "bold", padding: 0},
              children: []
            },
            %{
              type: :text,
              props: %{text: "How many stocks to simulate", text_size: :sm, text_color: :muted, padding: 0},
              children: []
            },
            %{type: :spacer, props: %{size: 12}, children: []},

            # Current value display
            %{
              type: :box,
              props: %{background: :surface_raised, padding: :space_md, corner_radius: :radius_md, fill_width: true},
              children: [
                %{
                  type: :text,
                  props: %{
                    text: "#{assigns.stock_count} stocks",
                    text_size: :"2xl",
                    text_color: :primary,
                    font_weight: "bold",
                    text_align: "center",
                    padding: 0
                  },
                  children: []
                }
              ]
            },
            %{type: :spacer, props: %{size: 12}, children: []},

            # Count preset buttons
            %{
              type: :row,
              props: %{fill_width: true, gap: 1},
              children: Enum.map(@count_presets, fn count ->
                active = assigns.stock_count == count
                %{
                  type: :button,
                  props: %{
                    text: "#{count}",
                    text_size: :sm,
                    weight: 1,
                    background: if(active, do: :primary, else: :surface),
                    text_color: if(active, do: :on_primary, else: :on_surface),
                    padding: :space_sx,
                    on_tap: {self(), {:set_stock_count, count}}
                  },
                  children: []
                }
              end)
            },

            %{type: :spacer, props: %{size: 32}, children: []},
            %{type: :divider, props: %{color: :border}, children: []},
            %{type: :spacer, props: %{size: 24}, children: []},

            # ── Persist to SQLite ────────────────────────────────────────
            %{
              type: :text,
              props: %{text: "Persist to SQLite", text_size: :lg, text_color: :on_surface, font_weight: "bold", padding: 0},
              children: []
            },
            %{
              type: :text,
              props: %{text: "Write every price tick to the local database", text_size: :sm, text_color: :muted, padding: 0},
              children: []
            },
            %{type: :spacer, props: %{size: 12}, children: []},

            %{
              type: :box,
              props: %{background: :surface_raised, padding: :space_md, corner_radius: :radius_md, fill_width: true},
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
                          props: %{
                            text: if(assigns.persist, do: "Enabled", else: "Disabled"),
                            text_size: :base,
                            text_color: if(assigns.persist, do: :green_400, else: :muted),
                            font_weight: "medium",
                            padding: 0
                          },
                          children: []
                        },
                        %{
                          type: :text,
                          props: %{
                            text: if(assigns.persist, do: "Recording price history", else: "No data saved to disk"),
                            text_size: :xs,
                            text_color: :muted,
                            padding: 0
                          },
                          children: []
                        }
                      ]
                    },
                    %{
                      type: :toggle,
                      props: %{
                        value: assigns.persist,
                        on_change: persist_toggle_change,
                        color: :primary
                      },
                      children: []
                    }
                  ]
                }
              ]
            },

            %{type: :spacer, props: %{size: 32}, children: []},
            %{type: :divider, props: %{color: :border}, children: []},
            %{type: :spacer, props: %{size: 24}, children: []},

            # ── Apply button ─────────────────────────────────────────────
            %{
              type: :button,
              props: %{
                text: "Apply Changes",
                background: :primary,
                text_color: :on_primary,
                text_size: :lg,
                font_weight: "bold",
                padding: :space_md,
                fill_width: true,
                on_tap: {self(), :apply}
              },
              children: []
            }
          ] ++ saved_notice ++ [
            %{type: :spacer, props: %{size: 32}, children: []},
            back_button()
          ]
        }
      ]
    }
  end

  def handle_info({:tap, {:set_interval, ms}}, socket) do
    {:noreply, Mob.Socket.assign(socket, interval: ms, saved: false)}
  end

  def handle_info({:tap, {:set_stock_count, count}}, socket) do
    {:noreply, Mob.Socket.assign(socket, stock_count: count, saved: false)}
  end

  def handle_info({:change, :persist_toggled, value}, socket) do
    {:noreply, Mob.Socket.assign(socket, persist: value, saved: false)}
  end

  def handle_info({:tap, :apply}, socket) do
    StockApp.StockSimulator.set_interval(socket.assigns.interval)
    StockApp.StockSimulator.set_stock_count(socket.assigns.stock_count)
    StockApp.StockSimulator.set_persist(socket.assigns.persist)

    if parent = socket.assigns.parent_pid, do: send(parent, :config_applied)

    {:noreply, Mob.Socket.assign(socket, saved: true)}
  end

  def handle_info({:tap, :back}, socket) do
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp header(title) do
    %{
      type: :text,
      props: %{
        text: title,
        text_size: :xl,
        text_color: :on_primary,
        background: :primary,
        padding: :space_md,
        fill_width: true
      },
      children: []
    }
  end

  defp back_button do
    %{
      type: :button,
      props: %{
        text: "← Back",
        background: :surface_raised,
        text_color: :on_surface,
        text_size: :lg,
        padding: :space_sm,
        fill_width: true,
        on_tap: {self(), :back}
      },
      children: []
    }
  end

  defp format_interval(ms) do
    cond do
      ms >= 60_000 -> "#{div(ms, 60_000)}m #{rem(ms, 60_000) |> div(1000)}s"
      ms >= 1_000  -> "#{div(ms, 1_000)}s"
      true         -> "#{ms}ms"
    end
  end
end

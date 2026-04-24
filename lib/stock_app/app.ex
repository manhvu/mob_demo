defmodule StockApp.App do
  @moduledoc "Application entry point for StockApp — a real-time stock price simulator."

  use Mob.App, theme: Mob.Theme.Obsidian

  @impl Mob.App
  def navigation(_platform) do
    tab_bar([
      stack(:stocks, root: StockApp.HomeScreen,  title: "Stocks"),
      stack(:config, root: StockApp.ConfigScreen, title: "Config")
    ])
  end

  @impl Mob.App
  def on_start do
    {:ok, _} = Application.ensure_all_started(:ecto_sqlite3)
    {:ok, _} = StockApp.Repo.start_link()
    Ecto.Migrator.with_repo(StockApp.Repo, fn repo ->
      Ecto.Migrator.run(repo, migrations_dir(), :up, all: true)
    end)

    {:ok, _} = StockApp.StockSimulator.start_link(interval: 2_000, stock_count: 10)

    Mob.Screen.start_root(StockApp.HomeScreen)
    Mob.Dist.ensure_started(node: :"stock_app_android@127.0.0.1", cookie: :mob_secret)
  end

  # Returns the path to the migrations directory for the current environment.
  #
  # WHY NOT Application.app_dir/2?
  #
  # Application.app_dir(app, "priv/repo/migrations") calls :code.priv_dir(app)
  # under the hood. That works in a normal `mix run` dev environment where the
  # app lives in $OTP_ROOT/lib/APP-VERSION/ebin/.
  #
  # On Android and iOS, Mob deploys .beam files to a flat -pa directory with no
  # versioned lib structure, so :code.priv_dir/1 returns {error, bad_name}.
  # Ecto.Migrator.run/3 silently finds zero migrations and logs "Migrations
  # already up" — tables are never created and any query against them crashes
  # the screen GenServer, making the screen appear frozen.
  #
  # The fix: mob_beam.c/mob_beam.m set MOB_BEAMS_DIR=beams_dir before erl_start.
  # The deployer pushes priv/ into beams_dir/priv/ and runs chmod -R 755 on it
  # (mkdir-as-root creates system:system drwxrwx--x dirs that the app process
  # can traverse but not list, breaking Path.wildcard). Here we read MOB_BEAMS_DIR
  # and pass the explicit path to Ecto.Migrator.run/4.
  defp migrations_dir do
    case System.get_env("MOB_BEAMS_DIR") do
      nil       -> Application.app_dir(:stock_app, "priv/repo/migrations")
      beams_dir -> Path.join([beams_dir, "priv", "repo", "migrations"])
    end
  end
end

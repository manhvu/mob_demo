# Intro

This is a basic mobile app for test [mob](https://hex.pm/packages/mob)

## GUIDE

### Install sdk

Install Android sdk and/or Xcode + simulator

### Init repo

```bash
mix deps.get

mix mob.install
# Run in the first time
mix mob.deploy --native
```

Watch change:

```bash
mix mob.watch
```

## Debug/Dev

Remote debub (join Elixir cluster):

```bash
iex -S mix mob.connect
```

View log & information from browser:

```bash
mix mob.server
```

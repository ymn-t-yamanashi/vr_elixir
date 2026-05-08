# ResoniteLinkEx

## 動かし方

### 1. 依存関係を入れる

```bash
cd resonite_link_ex
mix local.hex --force
mix local.rebar --force
mix deps.get
```

### 2. 一番簡単な立方体の出し方

Resonite 側で ResoniteLink を有効化してから実行します。

```elixir
{:ok, transport} = ResoniteLinkEx.Client.start_link()
ResoniteLinkEx.Shapes.spawn_cube(transport, name: "SimpleCube")
```

### 3. サンプルを実行する

```bash
mix run examples/sprint2_shapes_sample.exs
```

# ResoniteLinkEx

ResoniteLink 用の Elixir クライアント最小実装です。

## スプリント1対象

- `requestSessionData`
- `addSlot`
- `updateSlot`
- `addComponent`
- `updateComponent`
- `removeComponent`
- `removeSlot`

## 主な公開 API

- `ResoniteLinkEx.Core.request_session_data/1`
- `ResoniteLinkEx.Core.add_slot/2`
- `ResoniteLinkEx.Core.update_slot/2`
- `ResoniteLinkEx.Core.add_component/2`
- `ResoniteLinkEx.Core.update_component/2`
- `ResoniteLinkEx.Core.remove_component/2`
- `ResoniteLinkEx.Core.remove_slot/2`
- `ResoniteLinkEx.Core.get_slot/2`
- `ResoniteLinkEx.Client.start_link/1`
- `ResoniteLinkEx.Client.call/3`
- `ResoniteLinkEx.Objects.move_slot_by_name/4`
- `ResoniteLinkEx.Objects.delete_slot_by_name/3`
- `ResoniteLinkEx.Shapes.spawn_shape/3`
- `ResoniteLinkEx.PortDiscovery.find_resonite_link_port/0`

## 互換API

`ResoniteLinkEx` は既存呼び出しの移行先として残していますが、新規利用の入口にはしません。
今後は必要に応じて `Client` / `Core` / `Objects` / `Shapes` / `PortDiscovery` を直接使ってください。

## ホストでの品質ゲート

```bash
cd resonite_link_ex && mix local.hex --force && mix local.rebar --force && mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix check.docs && mix credo --strict && mix test --cover
```

## ドキュメント生成

```bash
cd resonite_link_ex && mix docs
```

## テスト方針

- `mix test` は Resonite 未起動でも実行できる（実機接続不要）。
- 実機接続が必要な検証は `@tag integration: true` を付け、`mix test --only integration` でのみ実行する。

## スプリント1実行手順

`docs/sprint1/スプリント1実行手順.md` を参照してください。

## サンプル実行（赤い正方形）

Resonite 側で ResoniteLink を有効化した状態で実行します。ポート指定は必須です。

```bash
mix run examples/red_square_sample.exs -- --port 9342
```

接続先ホストは `localhost` 固定です（`127.0.0.1` は使用しません）。

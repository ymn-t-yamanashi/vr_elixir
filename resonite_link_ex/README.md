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

- `ResoniteLinkEx.start_client/1`
- `ResoniteLinkEx.call/3`
- `ResoniteLinkEx.receive_response/2`
- `ResoniteLinkEx.Scene.supported_commands/0`
- `ResoniteLinkEx.Scene.quad_plan/2`

## ホストでの品質ゲート

```bash
cd resonite_link_ex && mix local.hex --force && mix local.rebar --force && mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix check.docs && mix credo --strict && mix test --cover
```

## テスト方針

- `mix test` は Resonite 未起動でも実行できる（実機接続不要）。
- 実機接続が必要な検証は `@tag integration: true` を付け、`mix test --only integration` でのみ実行する。

## フェイズ1実行手順

ルートの `フェイズ1実行手順.md` を参照してください。

## サンプル実行（赤い正方形）

Resonite 側で ResoniteLink を有効化した状態で実行します。ポート指定は必須です。

```bash
mix run examples/red_square_sample.exs -- --port 9342
```

接続先ホストは `localhost` 固定です（`127.0.0.1` は使用しません）。

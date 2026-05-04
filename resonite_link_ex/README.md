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

## Docker での品質ゲート

```bash
docker compose run --rm app bash -lc 'cd resonite_link_ex && mix local.hex --force && mix local.rebar --force && mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix check.docs && mix credo --strict && mix test --cover'
```

## フェイズ1実行手順

ルートの `フェイズ1実行手順.md` を参照してください。

# ResoniteLinkEx.Objects における send_command と Core 置換調査

## 調査日
- 2026-05-07

## 調査対象
- `lib/resonite_link_ex/objects.ex` の `defp send_command/3`
- `lib/resonite_link_ex/core.ex` の `update_slot/2`, `remove_slot/2`

## 現状（Objects.send_command の役割）
`ResoniteLinkEx.Objects` 内の `send_command/3` は、以下を実行している。

1. `client_or_transport` が Transport PID の場合
- `Transport.client_pid/1` で client を解決
- `build_transport_request/2` で送信用 JSON map を組み立て
- `Client.register_pending/3` を登録
- `Transport.send_json/2` で実送信
- 戻り値: `{:ok, %{"$type" => ..., ...}}`

2. Transport PID でない場合（fallback）
- `Core.update_slot/2` / `Core.remove_slot/2` を呼び出し
- `{:ok, %{type: ..., payload: ...}}` を `{:ok, %{"$type" => ..., "data" => ...}}` に再整形

## Core 置換可否（結論）
- **部分的に可能**
- **単純置換（send_command をそのまま Core に差し替え）は不可**

理由:
- `Core.update_slot/2` / `Core.remove_slot/2` は `Scene.call/3` 経由で「リクエスト生成」までしか行わず、`Transport.send_json/2` による実送信は行わない。
- `Objects` の公開API（`move_slot*`, `delete_slot*`）は現在「送信まで実行する」責務を持つため、単純に `Core` 呼び出しへ置換すると挙動が変わる。

## 置換マッピング
`Objects` 内の4箇所は、コマンド種別としては以下に対応する。

- `send_command(..., "updateSlot", %{slot_id: slot_id, position: position})`
  -> `Core.update_slot(client_or_transport, %{slot_id: slot_id, position: position})`

- `send_command(..., "removeSlot", %{slot_id: slot_id})`
  -> `Core.remove_slot(client_or_transport, %{slot_id: slot_id})`

対象箇所:
- `lib/resonite_link_ex/objects.ex:51`
- `lib/resonite_link_ex/objects.ex:85`
- `lib/resonite_link_ex/objects.ex:112`
- `lib/resonite_link_ex/objects.ex:136`

## 差分リスク（実装時に吸収が必要な点）
1. 送信責務の欠落
- Core は送信しないため、Transport PID 経路の実送信処理を別関数へ切り出して残す必要がある。

2. 戻り値形式の差
- Core 成功値: `{:ok, %{type: String.t(), payload: map()}}`
- Objects 現在値: `{:ok, %{"$type" => String.t(), "data" => map()}}`
- 既存API互換を維持するなら整形処理が必要。

3. pending 登録
- 既存 `send_command/3` は `Client.register_pending/3` を実施している。
- これを削除すると応答相関の仕組みが崩れるため、Transport送信経路では維持が必要。

## 推奨方針
1. `Objects` の公開APIは維持。
2. `send_command/3` の代わりに、以下へ責務分割して段階置換する。
- `build_request_via_core/2`（Coreでリクエスト生成）
- `send_over_transport/2`（pending登録 + Transport送信）
- `normalize_core_result/1`（戻り値整形）
3. テストで以下を固定。
- Transport PID 経路で実送信されること
- 戻り値形式が既存互換であること
- invalid_request 条件が維持されること

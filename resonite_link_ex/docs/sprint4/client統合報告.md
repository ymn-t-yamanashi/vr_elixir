# client / transport 統合報告

## 実施日
- 2026-05-07

## 依頼内容
- `client` と `transport` を 1 つのファイル `client` に統合する。

## 実施内容
- `lib/resonite_link_ex/transport.ex` の `ResoniteLinkEx.Transport` モジュール定義を `lib/resonite_link_ex/client.ex` の末尾へ移設。
- `lib/resonite_link_ex/transport.ex` を削除。
- モジュール名（`ResoniteLinkEx.Transport`）は変更していないため、既存の `alias ResoniteLinkEx.Transport` や呼び出しコードは互換維持。

## 影響範囲
- 変更あり:
  - `lib/resonite_link_ex/client.ex`
  - `docs/sprint4/client統合報告.md`
- 削除:
  - `lib/resonite_link_ex/transport.ex`

## 確認項目
- コンパイル、テスト、静的チェックが通ること（品質ゲート）。

## 追加調査: `ResoniteLinkEx.Transport` 完全削除前提

### 調査日
- 2026-05-07

### 結論
- `ResoniteLinkEx.Transport` は完全削除する前提で進める。
- ただし現状依存があるため、削除前に移行タスクを完了させる必要がある。

### 主要依存箇所（コード）
- `lib/resonite_link_ex/objects.ex`
  - `Transport.client_pid/1`
  - `Transport.send_json/2`
- `lib/resonite_link_ex/name_resolver.ex`
  - `default_get_slot/2` 内で `Transport.client_pid/1` と `Transport.send_json/2`
- `lib/resonite_link_ex/shapes.ex`
  - 既定送信関数に `&Transport.send_json/2`
  - `resolve_client_pid/2` で `Transport.client_pid/1`

### 主要依存箇所（利用例・テスト・文書）
- examples
  - `examples/sprint2_shapes_sample.exs`
  - `examples/sprint3_move_delete_by_name_sample.exs`
- tests
  - `test/resonite_link_ex/transport_test.exs`
  - `test/resonite_link_ex/objects_test.exs`
  - `test/resonite_link_ex/shapes_test.exs`
  - `test/resonite_link_ex/name_resolver_test.exs`
- docs
  - `docs/README.md`（`ResoniteLinkEx.Transport.start_link/2` 前提）

### 完全削除の実施方針
- `Transport` の責務を `Client` へ集約し、外部公開APIを `Client` 起点に統一する。
- `Transport` 名の互換レイヤ（委譲モジュール）は作らない。
- 破壊的変更として扱い、サンプル・テスト・README を同時更新する。
- モジュールファイルは増やさない（新規 `.ex` ファイルを追加しない）。
- 実装変更は既存ファイルの編集・統合のみで完結させる。

### 削除までの実施タスク
- 新IF定義:
  - 接続開始: `Client.start_link/2` 相当（現 `Transport.start_link/2` の置換）
  - 送信: `Client.send_json/2` 相当（現 `Transport.send_json/2` の置換）
  - client解決: `Client.client_pid/1` 相当（現 `Transport.client_pid/1` の置換）
- 参照置換:
  - `Objects` / `Shapes` / `NameResolver` の `Transport.*` 呼び出しを `Client.*` へ変更。
- テスト置換:
  - `transport_test.exs` を削除または `client_test.exs` へ統合。
  - `objects_test.exs` / `shapes_test.exs` / `name_resolver_test.exs` の起動・送信経路を新IFへ更新。
- ドキュメント置換:
  - `docs/README.md` と `examples/*.exs` の `ResoniteLinkEx.Transport` 記述を削除。
- 最終削除:
  - `defmodule ResoniteLinkEx.Transport` 本体を削除。
  - `alias ResoniteLinkEx.Transport` を全廃。

### 受け入れ条件（完全削除）
- `rg -n "ResoniteLinkEx\\.Transport|\\bTransport\\." resonite_link_ex` が 0 件（履歴ドキュメント除く運用なら対象パスを明示）。
- `mix compile --warnings-as-errors` 成功。
- `mix credo --strict` 成功。
- `mix test --cover` 成功。

## 実施結果（完全削除）

### 実施日
- 2026-05-07

### 実施内容
- `ResoniteLinkEx.Transport` モジュールを削除（定義全廃）。
- 送信・接続系APIを `ResoniteLinkEx.Client` に統一。
  - `Client.start_link/2`
  - `Client.send_json/2`
  - `Client.client_pid/1`
- WebSocket コールバック実装は同一ファイル内の `ResoniteLinkEx.Client` へ集約（新規ファイル追加なし）。
- 依存箇所の `Transport.*` 呼び出しを `Client.*` へ置換。
  - `lib/resonite_link_ex/objects.ex`
  - `lib/resonite_link_ex/name_resolver.ex`
  - `lib/resonite_link_ex/shapes.ex`
  - `examples/*.exs`
  - `test/*.exs`
  - `docs/README.md`

### 検証結果
- `rg -n "ResoniteLinkEx\\.Transport|\\bTransport\\." resonite_link_ex/lib resonite_link_ex/test resonite_link_ex/examples resonite_link_ex/docs/README.md` : 0件
- `mix compile --warnings-as-errors` : 成功
- `mix test --cover` : 成功（174 tests, 0 failures, Total 97.88%）

### 制約遵守
- モジュールファイル追加: なし
- 変更は既存ファイルの編集・統合のみで実施

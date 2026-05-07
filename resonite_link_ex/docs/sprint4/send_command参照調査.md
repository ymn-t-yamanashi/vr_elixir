# send_command 参照調査

## 調査対象
- `ResoniteLinkEx.Client.send_command/3`
- 実装定義: `lib/resonite_link_ex/client.ex`

## 定義箇所
- `lib/resonite_link_ex/client.ex:70`

## 呼び出し箇所（コードベース全体）
### 1. ライブラリ本体（lib）
- `lib/resonite_link_ex/client.ex:66`
  - `@doc` の `## Examples` 内で `ResoniteLinkEx.Client.send_command(:not_pid, "addSlot", %{})` を使用。

### 2. テスト（test）
- `test/resonite_link_ex/client_test.exs:34`
  - `send_command/3` の正常系テスト。
- `test/resonite_link_ex/client_test.exs:43`
  - `send_command/3` の未接続エラーテスト。

### 3. examples / README / docs
- 参照なし。

## まとめ
- 現在 `send_command/3` を直接呼んでいる実コードは、ライブラリ内部の例示（doc）と `client_test.exs` のみ。
- 本体ロジック（他モジュール）からの直接依存は検出されなかった。

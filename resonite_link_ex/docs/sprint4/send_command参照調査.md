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

## Coreモジュール置き換え可否

### 判定
- **置き換え可能（段階移行推奨）**

### 理由
1. `send_command/3` が扱うコマンドは、すでに `ResoniteLinkEx.Core` の個別関数で表現できる。
   - `requestSessionData` -> `Core.request_session_data/1`
   - `addSlot` -> `Core.add_slot/2`
   - `updateSlot` -> `Core.update_slot/2`
   - `addComponent` -> `Core.add_component/2`
   - `updateComponent` -> `Core.update_component/2`
   - `removeComponent` -> `Core.remove_component/2`
   - `removeSlot` -> `Core.remove_slot/2`
   - `getSlot` -> `Core.get_slot/2`

2. 現在の直接参照は `client.ex` の `@doc` 例と `client_test.exs` のみで、外部呼び出し依存が小さい。

### 置き換え時の注意点
- `send_command/3` を削除する場合、以下を同時更新する。
  - `lib/resonite_link_ex/client.ex` の `@doc` Examples
  - `test/resonite_link_ex/client_test.exs` の `send_command/3` 用テスト
- 互換性維持が必要なら、即削除ではなく非推奨化（deprecate）を先に行う。

### 推奨移行手順
1. 呼び出し側を `send_command/3` から `Core` 個別関数へ置換。
2. `send_command/3` を `@deprecated` 化し、一定期間併存。
3. 参照がゼロになった時点で `send_command/3` を削除。

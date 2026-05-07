# send_command 参照調査（再調査）

## 調査日
- 2026-05-07

## 調査対象
- `send_command` という識別子の参照全般
- 特に `ResoniteLinkEx.Client.send_command/3` の利用有無

## 調査コマンド
```bash
rg -n "send_command\(|Client\.send_command\(" lib test examples docs README.md
```

## 調査結果
### 1. `ResoniteLinkEx.Client.send_command/3`
- **定義なし**（`Client` モジュールからは削除済み）
- `lib` / `test` / `examples` / `README` / `docs` において、実行対象コードでの呼び出しは検出されない。

### 2. 残存している `send_command` 参照
- `lib/resonite_link_ex/objects.ex`
  - `send_command(...)` 呼び出し: 51, 85, 112, 136 行
  - `defp send_command/3` 定義: 157, 173 行
- これは `ResoniteLinkEx.Objects` 内部の **private helper (`defp`)** であり、`Client.send_command/3` とは別物。

### 3. ドキュメント上の参照
- `docs/sprint4/send_command参照調査.md`（本ファイル）以外に、`Client.send_command/3` を前提にした最新参照は検出されない。

## 結論
- `ResoniteLinkEx.Client.send_command/3` はすでに廃止済みで、現在のコードベースに実呼び出し箇所はない。
- 現在残る `send_command` は `Objects` モジュール内の private 関数のみで、公開APIの `Client.send_command/3` 参照ではない。

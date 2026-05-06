# 共通name解決API（スプリント3）

## 目的
- `name` 指定の移動・削除APIで共通に使う `name -> slot_id` 解決処理を1か所に集約する。
- 各APIで解決ロジックを重複実装しない。

## 公開I/F
- `resolve_slot_id(client_or_transport, name, opts \\ [])`
  - `name`: `String.t()`（必須）
  - `opts`:
    - `:parent_name`（任意、同名候補の絞り込み用）
  - 戻り値:
    - 成功: `{:ok, slot_id}`
    - 失敗: `{:error, :not_found | :ambiguous_name | :invalid_request | term()}`

## 解決ポリシー
1. `name` 完全一致で候補を取得する。
2. 候補が0件なら `{:error, :not_found}` を返す。
3. 候補が2件以上で `parent_name` 未指定なら `{:error, :ambiguous_name}` を返す。
4. `parent_name` 指定時は親条件で候補を絞り、1件に確定した場合のみ `slot_id` を返す。
5. `parent_name` で1件に絞れない場合は `{:error, :ambiguous_name}` を返す。

## getSlot前提
- 本スプリントでは `getSlot` を前提に、対象Slot情報の取得・検証を行う。
- 解決済み `slot_id` で移動時は `updateSlot`、削除時は `removeSlot` を呼び出す。
- `getSlot` は新規の特別実装にせず、既存関数（例: `addSlot` / `updateSlot` / `removeSlot`）と同じ実装レベルで扱う。
  - 具体的には `Protocol` の type許可・payload検証、`Scene` の対応コマンド、公開API、単体テストを同粒度でそろえる。

## 利用先
- `move_slot_by_name/4`
- `delete_slot_by_name/3`
- `spawn_shape/3` の既定親解決フロー（必要時）

## 実装上の注意
- 入力検証（`name` 非空文字列）を先に行う。
- エラー種別は既存方針（`:invalid_request` / `:not_found` / `:ambiguous_name`）に合わせる。
- 既存互換API（`slot_id` 前提）とは責務を分離し、段階移行可能な形にする。

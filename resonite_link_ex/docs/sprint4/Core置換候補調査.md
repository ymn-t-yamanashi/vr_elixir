# ResoniteLinkEx.Core 置換候補調査

## 1. 目的
- `ResoniteLinkEx.Scene.call` / `ResoniteLinkEx.call` / `Client.call` の直接利用箇所を確認し、`ResoniteLinkEx.Core` の個別関数へ置換可能な箇所を整理する。

## 2. 前提
- 対象コマンド（Coreが提供済み）
  - `requestSessionData`
  - `addSlot`
  - `updateSlot`
  - `addComponent`
  - `updateComponent`
  - `removeComponent`
  - `removeSlot`
  - `getSlot`

## 3. 置換可能箇所（実装コード）

### 3.1 `Client.send_command/3`
- 現在位置: `lib/resonite_link_ex/client.ex`
- 判定: **置換可能（対応済み）**
- 内容:
  - 文字列コマンドから `Core` 個別関数へ分岐することで、`Scene.call` の直接利用を避けられる。

### 3.2 `ResoniteLinkEx.call/3`
- 現在位置: `lib/resonite_link_ex.ex`
- 判定: **条件付きで置換可能**
- 理由:
  - 現在は「任意 `$type` を透過的に受ける統一IF」の役割。
  - `Core` は個別関数APIなので、`call/3` を単純置換すると「任意 `$type` 透過性」が失われる。
- 提案:
  - 方針A: 互換維持のため `ResoniteLinkEx.call/3` は残す。
  - 方針B: Core優先へ寄せるなら `ResoniteLinkEx.call/3` を段階的に非推奨化。

### 3.3 `NameResolver` / `Objects`
- `lib/resonite_link_ex/name_resolver.ex` の `Client.call(..., "getSlot", ...)`
- `lib/resonite_link_ex/objects.ex` の `Client.call(target_pid, type, payload)`
- 判定: **置換可能（ただし要注意）**
- 理由:
  - `getSlot` は `Core.get_slot/2` へ置換可能。
  - `Objects` の fallback は type 動的なので、Core個別関数へ分岐が必要。
- 注意点:
  - 既存の低レイヤ fallback は transport/client 両対応のため、置換時に責務境界を崩さないこと。

## 4. 置換不要または対象外

### 4.1 `Core` 内部の `Scene.call`
- 現在位置: `lib/resonite_link_ex/core.ex`
- 判定: **置換不要**
- 理由:
  - CoreはSceneの薄いラッパとして設計されており、ここは実装詳細として許容。

### 4.2 `scene_test.exs`
- 現在位置: `test/resonite_link_ex/scene_test.exs`
- 判定: **置換対象外**
- 理由:
  - `Scene` モジュール自体の単体テストであり、`Scene.call` を直接検証するのが目的。

### 4.3 ドキュメント内の設計記述
- 現在位置: `docs/sprint3/オブジェクト操作モジュール設計.md`
- 判定: **任意で更新**
- 理由:
  - 実装コードではないが、最新方針（Core優先）に寄せるなら文面更新は有効。

## 5. 具体的な置換マッピング
- `Scene.call(client, "requestSessionData", %{})` -> `Core.request_session_data(client)`
- `Scene.call(client, "addSlot", payload)` -> `Core.add_slot(client, payload)`
- `Scene.call(client, "updateSlot", payload)` -> `Core.update_slot(client, payload)`
- `Scene.call(client, "addComponent", payload)` -> `Core.add_component(client, payload)`
- `Scene.call(client, "updateComponent", payload)` -> `Core.update_component(client, payload)`
- `Scene.call(client, "removeComponent", payload)` -> `Core.remove_component(client, payload)`
- `Scene.call(client, "removeSlot", payload)` -> `Core.remove_slot(client, payload)`
- `Scene.call(client, "getSlot", payload)` -> `Core.get_slot(client, payload)`

## 6. 結論
- Core置換が有効な主対象は、**アプリケーション利用コード（Client/Objects/NameResolverの高レベル分岐）**。
- 一方、**Sceneそのものの実装・Scene単体テスト**は置換対象外。
- 現時点で最小リスク方針は、
  - `send_command/3` の Core分岐を維持
  - `ResoniteLinkEx.call/3` は互換のため残す
  - 残る動的fallback（Objects/NameResolver）を段階的にCore経由へ移行する

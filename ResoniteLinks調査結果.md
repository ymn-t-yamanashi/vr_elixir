# ResoniteLink 調査結果（2026-05-05）

## 目的
「ResoniteLink がポート表示されているのに、WebSocket接続時に 404 になる」症状が、他でも起きているかを調査し、現時点の対処方針を整理する。

## 結論（先に要点）
- **ResoniteLink公式リポジトリの公開ドキュメント/コード上では、同一症状を直接報告した Issue は確認できなかった。**
- ただし、公式実装・ドキュメントから見ると、接続方式は一貫して以下。
  - 接続先は `ws://localhost:{linkPort}`（基本 path なし）
  - `linkPort` は UDP `12512` のアナウンス（またはUI表示/ログ）由来
- そのため、今回の `404` は「ResoniteLink の WebSocket エンドポイントに当たっていない（ポート不一致・対象不一致・実行条件不一致）」可能性が高い。
- 実地検証での確定原因として、**`127.0.0.1` 指定では接続失敗し、`localhost` 指定で接続成功** する環境差が確認された。

## 調査ソース
- ResoniteLink 公式リポジトリ
  - https://github.com/Yellow-Dog-Man/ResoniteLink
- Setup ドキュメント
  - https://github.com/Yellow-Dog-Man/ResoniteLink/blob/master/docs/docs/setup.md
- 公式C#実装（接続ロジック）
  - `ResoniteLink/LinkInterface.cs`
- 公式C#実装（UDP discovery）
  - `ResoniteLink/LinkSessionListener.cs`
- 参考 gist（運用知見）
  - https://gist.github.com/herbst17904634/1fbe18cceedb96ffa5267006b8319383

## 事実確認
### 1. 公式の接続前提
- setup.md では「Resonite 側で Enable ResoniteLink を有効化し、表示されたポートへ外部アプリから接続」と記載。
- headless では `enableResoniteLink` / `forceResoniteLinkPort` が案内されている。

### 2. 公式クライアント実装
- `LinkInterface.Connect(Uri target, ...)` は `ClientWebSocket.ConnectAsync(target, ...)` を実行。
- コード上で固定 path 付与は見当たらず、渡された URI に接続する構造。

### 3. 公式 discovery 実装
- `LinkSessionListener` は UDP `12512` を listen。
- 受信JSONから `sessionId`, `linkPort` を管理し、`linkPort < 0` はセッション終了扱い。

## 今回症状との対応
- 実測では、複数ポートに対して WebSocket upgrade を試行した結果、`404` または timeout が発生。
- `404` は「WebSocketとしては不正な接続先（HTTP側が Not Found を返す）」と整合。
- したがって、コードの軽微差よりも、**接続先特定プロセス（discovery/ログ/対象セッション）** の問題である可能性が高い。

## 今回の確定原因（実測）
- 原因:
  - `127.0.0.1` で接続していたこと
- 解決:
  - `localhost` に変更したところ接続成功
- 結果:
  - 本件では「ポートだけでなくホスト名指定も接続条件に影響する」ことを確認

### 再発防止ルール（本PJ向け）
- ResoniteLink接続時の既定ホストは `localhost` を優先する。
- `127.0.0.1` は代替候補扱いにし、失敗時は即 `localhost` に切り替えて再試行する。

## 他ユーザー同症状について
- 公式リポジトリの公開情報範囲では、今回と同一条件（Resonite UIで有効化済み・ポート表示あり・WS 404）を明示した再現報告は確認できなかった。
- ただし、WebSocket一般論として `404` は「エンドポイント不一致」を示すため、ResoniteLinkでも同じ分類で切り分けるのが妥当。

## 推奨方針（実装変更前）
1. `linkPort` は手入力固定ではなく、UDP `12512` / 最新ログ / UI表示を優先して都度決定する。
2. 接続可否判定は `HTTP 101 Switching Protocols` を成功条件に統一する。
3. セッション切替時にポートが変わる前提で、再接続時は discovery を再実行する。
4. それでも `404` が続く場合は、Resonite側の実行条件（対象セッション/権限/バージョン）を優先確認する。

## 補足
- 参考 gist では、上記の discovery + 101 判定 + 再接続戦略が手順化されており、今回の切り分け方針と整合している。

## 公式以外の事例調査（追加）
### 結果要約
- **「ResoniteLink でポート表示はあるのに WS が 404」の同一事例を、公開Web上で明示的に確認できた件数は少ない（少なくとも一般検索では有意な蓄積を確認できず）。**
- 一方で、Resonite Wiki のトラブルシュート項目には、今回症状と整合する失敗要因が複数記載されている。

### 参考になった非公式情報
1. Resonite Wiki: `Troubleshooting:Websockets`
   - WebSocket利用時のチェックリストとして、以下が明示されている。
     - アドレス/ポートが正しいか
     - `ws://` or `wss://` を使っているか
     - サーバが起動しているか
     - `User` プロパティがサーバ実行者と一致しているか
     - Web Hosts で Denied されていないか（Denied の場合は設定削除して再許可）
   - URL: https://wiki.resonite.com/Troubleshooting%3AWebsockets

2. コミュニティ gist（運用手順）
   - UDP `12512` アナウンス由来の `linkPort` を使い、`101 Switching Protocols` を成功判定にする運用を提案。
   - 手入力ポート固定より、discovery 再取得で追従する方針。
   - URL: https://gist.github.com/herbst17904634/1fbe18cceedb96ffa5267006b8319383

### 今回症状との対応づけ（非公式情報ベース）
- `404` は「対象エンドポイント不一致」の典型で、上記チェックリストと整合。
- 特に `Web Hosts` の Denied、`User` 不一致、古いポート固定は再現原因になり得る。

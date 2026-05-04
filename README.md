# vr_elixir

Resonite を Elixir から外部操作するための設計ドキュメントを管理するリポジトリです。  
接続方式は **ResoniteLink のみ** を対象とします。

## プロジェクト命名
- Mixプロジェクト名: `:resonite_link_ex`
- ルートモジュール名: `ResoniteLinkEx`

## ドキュメント
- `基本設計.md`: 目的、対象範囲、できること、全体方針
- `詳細設計.md`: ResoniteLink 公式モデル準拠の詳細設計
- `PJルール.md`: プロジェクト運用ルール

## 補足
実装コードは今後追加予定です。現時点では設計ドキュメントを主対象としています。

## Docker実行（Make）
- `make up`: アプリをDockerで起動（`mix run --no-halt`）
- `make test`: Docker内で `mix test` を実行
- `make format`: Docker内で `mix format --check-formatted` を実行
- `make credo`: Docker内で `mix credo --strict` を実行
- `make check`: `format` → `credo` → `test` を順に実行

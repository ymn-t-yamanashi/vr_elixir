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

## 実行手順
- Docker内での品質ゲート実行手順は `.codex/skills/elixir-quality-gate/SKILL.md` を参照する。
- コミット前チェック手順は `.codex/skills/commit-gate-jp/SKILL.md` を参照する。

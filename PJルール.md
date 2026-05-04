# PJルール

## Git運用
- コミットメッセージは必ず日本語で記述する。
- 必要に応じてブランチ名・PRタイトル・PR説明も日本語で記述する。
- 各コメントは日本語で記述する。

## 設計時ルール
- ResoniteLink を前提に設計する場合、設計開始前に必ず ResoniteLink の最新情報を確認する。
- 確認先は以下を一次情報として固定する。
  - ResoniteLink 公式リポジトリ: https://github.com/Yellow-Dog-Man/ResoniteLink
  - ResoniteLink リリース一覧: https://github.com/Yellow-Dog-Man/ResoniteLink/releases
  - Resonite 公式更新情報（Steam Community）: https://steamcommunity.com/app/2519830/allnews/
- 設計書には「確認日」と「確認した最新バージョン/更新項目」を記録してから設計を確定する。
- 設計・実装で使用する命名（メッセージ名、フィールド名、型名）は公式仕様の命名に従う。

## 開発環境ルール
- 開発はDocker環境で行う。

## 壁打ち時ルール
- 壁打ち中は、ユーザーの明示的な作業指示（例: 「作って」「編集して」）があるまで、ファイルの作成・編集・削除を禁止する。
- 作成時は、こまめに確認できるよう最小単位で作成を進める。

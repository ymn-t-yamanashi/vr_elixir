---
name: elixir-quality-gate
description: Elixir変更時に、このPJの品質ゲート（Docker内で format/compile/check.docs/credo/test --cover）を実行し、失敗原因を最小差分で解消する。Elixirコード編集、コミット前確認、カバレッジ確認時に使う。
---

# Elixir Quality Gate

## 概要
このスキルは、このPJで Elixir 変更を行った後に品質ゲートを実行し、失敗を最小修正で解消するための手順を提供する。

## 利用タイミング
- `resonite_link_ex` 配下の `.ex` / `.exs` を編集したとき
- コミット前に品質確認するとき
- カバレッジ確認が必要なとき

## 手順
1. 変更対象を最小単位で確定する（可能ならファイル単位）。
2. Docker内で以下を順に実行する。
```bash
docker compose run --rm app bash -lc "cd resonite_link_ex && mix local.hex --force && mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix check.docs && mix credo --strict && mix test --cover"
```
3. 失敗時は該当ファイルのみ最小修正し、再実行する。
4. すべて成功したらコミットする。

## 失敗時の対応
- `format` 失敗: 指摘ファイルのみ整形。
- `compile --warnings-as-errors` 失敗: 警告を解消。
- `check.docs` 失敗: 公開関数に `@doc` を追加。
- `credo --strict` 失敗: 指摘を最小修正。
- `test --cover` 失敗: 未カバー分岐をテスト追加で解消（原則先にテスト）。

## 参照
- 品質基準値・必須条件・禁止事項は `Elixirルール.md` を正本とする。

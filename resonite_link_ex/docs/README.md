# ResoniteLinkEx はじめに

このページは、ResoniteLinkEx を初めて使う人向けの最初のガイドです。  
「まず何をすれば動くか」を最短で確認できます。

## これは何ができるライブラリか

ResoniteLinkEx は、Elixir から ResoniteLink に接続して以下を行うためのライブラリです。

- セッション接続の初期化
- オブジェクトの移動・削除
- 基本図形の生成
- 接続先ポートの自動検出

## 最初の流れ

1. クライアントを起動する  
2. （必要なら）ポートを検出する  
3. Transport を開始する  
4. API を呼び出す

## 最小例

```elixir
{:ok, port} = ResoniteLinkEx.find_resonite_link_port()
{:ok, transport} = ResoniteLinkEx.Client.start_link(host: "localhost", port: port, path: "")
{:ok, client} = ResoniteLinkEx.Client.client_pid(transport)

# 例: cube を生成
{:ok, _ids} =
  ResoniteLinkEx.spawn_shape(transport, :cube,
    name: "SampleCube",
    client_pid: client
  )
```

## よく使う API

- `ResoniteLinkEx.start_client/1`
- `ResoniteLinkEx.find_resonite_link_port/0`
- `ResoniteLinkEx.spawn_shape/3`
- `ResoniteLinkEx.move_slot_by_name/4`
- `ResoniteLinkEx.delete_slot_by_name/3`

## つまずきやすい点

- `client` と `transport` を混同しない。
- 名前指定APIでは対象名が一致しないと `:not_found` になる。
- 接続直後はセッション準備が完了するまで応答待ちが必要になる場合がある。

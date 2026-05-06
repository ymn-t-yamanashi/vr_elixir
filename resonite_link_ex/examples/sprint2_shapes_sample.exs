defmodule Sprint2ShapesSample do
  @moduledoc """
  スプリント2対象の7図形を順番に生成するサンプル。

  初学者向けに、処理手順を上から順に追える構成にしている。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Shapes
  alias ResoniteLinkEx.Transport

  @host "localhost"

  def run do
    # 1) ポートを受け取る
    port = parse_port(System.argv())

    # 2) クライアントとトランスポートを起動する
    {:ok, client} = ResoniteLinkEx.start_client()
    {:ok, transport} = Transport.start_link(client, host: @host, port: port, path: "")

    # 3) セッション準備完了を待つ
    wait_session_ready(client, 30)

    # 4) 7図形を順番に生成する
    spawn_quad!(transport)
    spawn_cube!(transport)
    spawn_sphere!(transport)
    spawn_cylinder!(transport)
    spawn_capsule!(transport)
    spawn_ring!(transport)
    spawn_grid!(transport)

    IO.puts("7図形の生成要求を送信しました。")
    :ok
  end

  defp spawn_quad!(transport),
    do:
      spawn_with_opts!(
        :quad,
        Shapes.spawn_quad(transport,
          name: "Sprint2Quad",
          parent_id: "Root",
          position: %{"x" => -1.8, "y" => 1.4, "z" => 0.5},
          scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
          color: %{"r" => 1, "g" => 0.2, "b" => 0.2, "a" => 1}
        )
      )

  defp spawn_cube!(transport),
    do:
      spawn_with_opts!(
        :cube,
        Shapes.spawn_cube(transport,
          name: "Sprint2Cube",
          parent_id: "Root",
          position: %{"x" => -1.2, "y" => 1.4, "z" => 0.5},
          scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
          color: %{"r" => 0.2, "g" => 0.2, "b" => 1, "a" => 1}
        )
      )

  defp spawn_sphere!(transport),
    do:
      spawn_with_opts!(
        :sphere,
        Shapes.spawn_sphere(transport,
          name: "Sprint2Sphere",
          parent_id: "Root",
          position: %{"x" => -0.6, "y" => 1.4, "z" => 0.5},
          scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
          color: %{"r" => 0.2, "g" => 1, "b" => 0.2, "a" => 1}
        )
      )

  defp spawn_cylinder!(transport),
    do:
      spawn_with_opts!(
        :cylinder,
        Shapes.spawn_cylinder(transport,
          name: "Sprint2Cylinder",
          parent_id: "Root",
          position: %{"x" => 0.0, "y" => 1.4, "z" => 0.5},
          scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
          color: %{"r" => 1, "g" => 0.9, "b" => 0.2, "a" => 1}
        )
      )

  defp spawn_capsule!(transport),
    do:
      spawn_with_opts!(
        :capsule,
        Shapes.spawn_capsule(transport,
          name: "Sprint2Capsule",
          parent_id: "Root",
          position: %{"x" => 0.6, "y" => 1.4, "z" => 0.5},
          scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
          color: %{"r" => 1, "g" => 0.5, "b" => 0.2, "a" => 1}
        )
      )

  defp spawn_ring!(transport),
    do:
      spawn_with_opts!(
        :ring,
        Shapes.spawn_ring(transport,
          name: "Sprint2Ring",
          parent_id: "Root",
          position: %{"x" => 1.2, "y" => 1.4, "z" => 0.5},
          scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
          color: %{"r" => 0.8, "g" => 0.3, "b" => 1, "a" => 1}
        )
      )

  defp spawn_grid!(transport),
    do:
      spawn_with_opts!(
        :grid,
        Shapes.spawn_grid(transport,
          name: "Sprint2Grid",
          parent_id: "Root",
          position: %{"x" => 1.8, "y" => 1.4, "z" => 0.5},
          scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
          color: %{"r" => 0.2, "g" => 1, "b" => 1, "a" => 1}
        )
      )

  defp spawn_with_opts!(shape, {:ok, ids}) do
    IO.puts("生成要求送信: #{shape} slot_id=#{ids.slot_id}")
    Process.sleep(120)
    :ok
  end

  defp spawn_with_opts!(shape, {:error, reason}) do
    raise "図形生成に失敗: shape=#{shape} reason=#{inspect(reason)}"
  end

  defp wait_session_ready(_client, 0) do
    raise "session_ready が true になりませんでした。ResoniteLink 接続状態を確認してください。"
  end

  defp wait_session_ready(client, retry_left) do
    if Client.session_ready?(client) do
      :ok
    else
      Process.sleep(100)
      wait_session_ready(client, retry_left - 1)
    end
  end

  defp parse_port(args) do
    cleaned = Enum.reject(args, &(&1 == "--"))

    case cleaned do
      ["--port", port_text | _rest] -> parse_port_value(port_text)
      [port_text | _rest] -> parse_port_value(port_text)
      [] -> raise("ポート指定は必須です。例: mix run examples/sprint2_shapes_sample.exs -- --port 9341")
    end
  end

  defp parse_port_value(port_text) do
    case Integer.parse(port_text) do
      {port, ""} when port > 0 and port <= 65_535 -> port
      _ -> raise "ポート指定が不正です。1-65535 の整数を指定してください。例: --port 9341"
    end
  end
end

Sprint2ShapesSample.run()

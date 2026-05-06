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
    Shapes.spawn_quad(transport,
      name: "Sprint2Quad",
      position: %{"x" => -1.8, "y" => 1.4, "z" => 0.5},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 1, "g" => 0.2, "b" => 0.2, "a" => 1}
    )
    |> handle_spawn_result!(:quad)

    Shapes.spawn_cube(transport,
      name: "Sprint2Cube",
      position: %{"x" => -1.2, "y" => 1.4, "z" => 0.5},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 0.2, "g" => 0.2, "b" => 1, "a" => 1}
    )
    |> handle_spawn_result!(:cube)

    Shapes.spawn_sphere(transport,
      name: "Sprint2Sphere",
      position: %{"x" => -0.6, "y" => 1.4, "z" => 0.5},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 0.2, "g" => 1, "b" => 0.2, "a" => 1}
    )
    |> handle_spawn_result!(:sphere)

    Shapes.spawn_cylinder(transport,
      name: "Sprint2Cylinder",
      position: %{"x" => 0.0, "y" => 1.4, "z" => 0.5},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 1, "g" => 0.9, "b" => 0.2, "a" => 1}
    )
    |> handle_spawn_result!(:cylinder)

    Shapes.spawn_capsule(transport,
      name: "Sprint2Capsule",
      position: %{"x" => 0.6, "y" => 1.4, "z" => 0.5},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 1, "g" => 0.5, "b" => 0.2, "a" => 1}
    )
    |> handle_spawn_result!(:capsule)

    Shapes.spawn_ring(transport,
      name: "Sprint2Ring",
      position: %{"x" => 1.2, "y" => 1.4, "z" => 0.5},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 0.8, "g" => 0.3, "b" => 1, "a" => 1}
    )
    |> handle_spawn_result!(:ring)

    Shapes.spawn_grid(transport,
      name: "Sprint2Grid",
      position: %{"x" => 1.8, "y" => 1.4, "z" => 0.5},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 0.2, "g" => 1, "b" => 1, "a" => 1}
    )
    |> handle_spawn_result!(:grid)

    IO.puts("7図形の生成要求を送信しました。")
    :ok
  end

  defp handle_spawn_result!({:ok, ids}, shape) do
    IO.puts("生成要求送信: #{shape} slot_id=#{ids.slot_id}")
    :ok
  end

  defp handle_spawn_result!({:error, reason}, shape) do
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
      [] -> detect_port!()
    end
  end

  defp parse_port_value(port_text) do
    case Integer.parse(port_text) do
      {port, ""} when port > 0 and port <= 65_535 -> port
      _ -> raise "ポート指定が不正です。1-65535 の整数を指定してください。例: --port 9341"
    end
  end

  defp detect_port! do
    case ResoniteLinkEx.find_resonite_link_port() do
      {:ok, port} ->
        IO.puts("ポート自動検出: #{port}")
        port

      {:error, :port_not_found} ->
        raise """
        ポートを自動検出できませんでした。
        ResoniteLinkを有効化するか、--port で明示指定してください。
        """

      {:error, reason} ->
        raise "ポート検出に失敗しました: #{inspect(reason)}"
    end
  end
end

Sprint2ShapesSample.run()

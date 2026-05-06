defmodule NDRoadsterSample do
  @moduledoc """
  NDロードスターをレゴ風ブロックで再現するサンプル。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Shapes
  alias ResoniteLinkEx.Transport

  @host "localhost"
  @unit 0.08

  def run do
    port = parse_port(System.argv())
    {:ok, client} = ResoniteLinkEx.start_client()
    {:ok, transport} = Transport.start_link(client, host: @host, port: port, path: "")
    wait_session_ready(client, 30)

    cubes = build_cubes()

    cubes
    |> Enum.with_index(1)
    |> Enum.each(fn {cube, index} ->
      spawn_cube!(transport, cube, index)
    end)

    IO.puts("NDロードスターを生成しました。cube数=#{length(cubes)}")
  end

  defp spawn_cube!(transport, cube, index) do
    result =
      Shapes.spawn_cube(transport,
        name: "nd_roadster_cube_#{index}",
        parent_id: "Root",
        position: %{
          "x" => cube.x * @unit,
          "y" => cube.y * @unit,
          "z" => cube.z * @unit
        },
        scale: %{"x" => @unit, "y" => @unit, "z" => @unit},
        color: cube.color
      )

    case result do
      {:ok, _ids} ->
        if rem(index, 200) == 0, do: IO.puts("配置中... #{index} cubes")
        :ok

      {:error, reason} ->
        raise "cube生成失敗 index=#{index} reason=#{inspect(reason)}"
    end
  end

  defp build_cubes do
    base =
      body_shell() ++
        hood() ++
        trunk() ++
        windshield() ++
        cabin() ++
        fenders() ++
        side_lines() ++ lights() ++ grille() ++ tires() ++ mirrors()

    dedup(base)
  end

  defp body_shell do
    for x <- -34..34,
        z <- -11..11,
        y <- 0..6,
        abs(z) <= width_limit(x),
        do: cube(x, y, z, red_body())
  end

  defp hood do
    for x <- 16..34,
        z <- -9..9,
        y <- 7..11,
        abs(z) <= 9 - div(34 - x, 4),
        do: cube(x, y, z, red_body())
  end

  defp trunk do
    for x <- -34..-16,
        z <- -9..9,
        y <- 7..10,
        abs(z) <= 9 - div(x + 34, 5),
        do: cube(x, y, z, red_body())
  end

  defp windshield do
    for x <- 5..16,
        z <- -7..7,
        y <- 10..16,
        abs(z) <= 7,
        do: cube(x, y, z, glass())
  end

  defp cabin do
    for x <- -13..5,
        z <- -7..7,
        y <- 10..14,
        abs(z) <= 7,
        do: cube(x, y, z, black_trim())
  end

  defp fenders do
    front =
      for x <- 18..31,
          z <- -13..13,
          y <- 4..10,
          abs(z) >= 8 and abs(z) <= 13 do
        cube(x, y, z, red_body())
      end

    rear =
      for x <- -31..-18,
          z <- -13..13,
          y <- 4..9,
          abs(z) >= 8 and abs(z) <= 13 do
        cube(x, y, z, red_body())
      end

    front ++ rear
  end

  defp side_lines do
    for x <- -30..28,
        y <- 6..7,
        z <- [-12, 12],
        rem(x, 3) != 0,
        do: cube(x, y, z, shadow_red())
  end

  defp lights do
    head =
      for z <- -5..5, rem(z, 2) == 0 do
        cube(34, 6, z, headlight())
      end

    tail =
      for z <- -5..5, rem(z, 2) == 0 do
        cube(-34, 6, z, taillight())
      end

    head ++ tail
  end

  defp grille do
    for x <- 31..34,
        z <- -6..6,
        y <- 2..5,
        rem(z, 2) == 0,
        do: cube(x, y, z, grille_gray())
  end

  defp tires do
    wheel_positions = [{22, -13}, {22, 13}, {-22, -13}, {-22, 13}]

    for {x0, z0} <- wheel_positions,
        x <- (x0 - 4)..(x0 + 4),
        z <- (z0 - 2)..(z0 + 2),
        y <- -2..5,
        do: cube(x, y, z, tire())
  end

  defp mirrors do
    [
      cube(8, 12, -10, silver()),
      cube(8, 12, 10, silver())
    ]
  end

  defp width_limit(x) when x >= 26, do: 7
  defp width_limit(x) when x >= 10, do: 9
  defp width_limit(x) when x >= -10, do: 11
  defp width_limit(x) when x >= -26, do: 10
  defp width_limit(_x), do: 9

  defp cube(x, y, z, color), do: %{x: x, y: y + 1.0, z: z, color: color}

  defp dedup(cubes) do
    cubes
    |> Enum.reduce(%{}, fn cube, acc -> Map.put(acc, {cube.x, cube.y, cube.z}, cube) end)
    |> Map.values()
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

  defp red_body, do: %{"r" => 0.82, "g" => 0.08, "b" => 0.12, "a" => 1.0}
  defp shadow_red, do: %{"r" => 0.66, "g" => 0.06, "b" => 0.1, "a" => 1.0}
  defp black_trim, do: %{"r" => 0.08, "g" => 0.08, "b" => 0.1, "a" => 1.0}
  defp glass, do: %{"r" => 0.45, "g" => 0.65, "b" => 0.78, "a" => 0.8}
  defp tire, do: %{"r" => 0.05, "g" => 0.05, "b" => 0.05, "a" => 1.0}
  defp headlight, do: %{"r" => 0.95, "g" => 0.95, "b" => 0.75, "a" => 1.0}
  defp taillight, do: %{"r" => 0.92, "g" => 0.2, "b" => 0.2, "a" => 1.0}
  defp grille_gray, do: %{"r" => 0.23, "g" => 0.23, "b" => 0.24, "a" => 1.0}
  defp silver, do: %{"r" => 0.72, "g" => 0.72, "b" => 0.74, "a" => 1.0}
end

NDRoadsterSample.run()

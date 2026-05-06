defmodule BlueCubeSample do
  @moduledoc """
  ResoniteLinkEx ライブラリ経由で青い立方体（BoxMesh）を生成するサンプル。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Transport

  @host "localhost"

  def run do
    port = parse_port(System.argv())
    suffix = UUID.uuid4() |> String.slice(0, 8)
    ids = build_ids(suffix)

    {:ok, client} = ResoniteLinkEx.start_client()
    {:ok, transport} = Transport.start_link(client, host: @host, port: port, path: "")
    wait_session_ready(client, 20)

    send_add_slot(transport, ids)
    send_add_box_mesh(transport, ids)
    send_add_pbs_metallic(transport, ids)
    send_add_mesh_renderer(transport, ids)
    send_update_mesh_renderer(transport, ids)
    send_update_material_color(transport, ids)

    Process.sleep(500)
    :ok
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

  defp send_json!(transport, payload) do
    payload_with_message_id = Map.put(payload, "messageId", UUID.uuid4())

    case Transport.send_json(transport, payload_with_message_id) do
      :ok ->
        Process.sleep(120)
        :ok

      {:error, reason} ->
        raise "send_json failed: #{inspect(reason)}"
    end
  end

  defp send_add_slot(transport, ids) do
    send_json!(transport, %{
      "$type" => "addSlot",
      "data" => %{
        "id" => ids.slot_id,
        "parent" => %{"$type" => "reference", "targetId" => "Root"},
        "name" => %{"$type" => "string", "value" => "BlueCubeSample"},
        "position" => %{"$type" => "float3", "value" => %{"x" => 0, "y" => 1.4, "z" => 0.5}},
        "scale" => %{"$type" => "float3", "value" => %{"x" => 0.5, "y" => 0.5, "z" => 0.5}}
      }
    })
  end

  defp send_add_box_mesh(transport, ids) do
    send_json!(transport, %{
      "$type" => "addComponent",
      "containerSlotId" => ids.slot_id,
      "data" => %{
        "id" => ids.mesh_id,
        "componentType" => "[FrooxEngine]FrooxEngine.BoxMesh"
      }
    })
  end

  defp send_add_pbs_metallic(transport, ids) do
    send_json!(transport, %{
      "$type" => "addComponent",
      "containerSlotId" => ids.slot_id,
      "data" => %{
        "id" => ids.material_id,
        "componentType" => "[FrooxEngine]FrooxEngine.PBS_Metallic"
      }
    })
  end

  defp send_add_mesh_renderer(transport, ids) do
    send_json!(transport, %{
      "$type" => "addComponent",
      "containerSlotId" => ids.slot_id,
      "data" => %{
        "id" => ids.renderer_id,
        "componentType" => "[FrooxEngine]FrooxEngine.MeshRenderer",
        "members" => %{
          "Mesh" => %{"$type" => "reference", "targetId" => ids.mesh_id}
        }
      }
    })
  end

  defp send_update_mesh_renderer(transport, ids) do
    send_json!(transport, %{
      "$type" => "updateComponent",
      "data" => %{
        "id" => ids.renderer_id,
        "members" => %{
          "Materials" => %{
            "$type" => "list",
            "elements" => [%{"$type" => "reference", "targetId" => ids.material_id}]
          }
        }
      }
    })
  end

  defp send_update_material_color(transport, ids) do
    send_json!(transport, %{
      "$type" => "updateComponent",
      "data" => %{
        "id" => ids.material_id,
        "members" => %{
          "AlbedoColor" => %{
            "$type" => "colorX",
            "value" => %{"r" => 0, "g" => 0, "b" => 1, "a" => 1}
          }
        }
      }
    })
  end

  defp build_ids(suffix) do
    %{
      slot_id: "sample_blue_cube_slot_#{suffix}",
      mesh_id: "sample_blue_cube_mesh_#{suffix}",
      material_id: "sample_blue_cube_mat_#{suffix}",
      renderer_id: "sample_blue_cube_renderer_#{suffix}"
    }
  end

  defp parse_port(args) do
    cleaned = Enum.reject(args, &(&1 == "--"))

    case cleaned do
      ["--port", port_text | _rest] -> parse_port_value(port_text)
      [port_text | _rest] -> parse_port_value(port_text)
      [] -> raise("ポート指定は必須です。例: mix run examples/blue_cube_sample.exs -- --port 11943")
    end
  end

  defp parse_port_value(port_text) do
    case Integer.parse(port_text) do
      {port, ""} when port > 0 and port <= 65_535 -> port
      _ -> raise "ポート指定が不正です。1-65535 の整数を指定してください。例: --port 11943"
    end
  end
end

BlueCubeSample.run()

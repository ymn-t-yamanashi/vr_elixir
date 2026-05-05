defmodule RedSquareSample do
  @moduledoc """
  ResoniteLink へ接続し、赤い正方形（Quad）を生成するサンプル。
  """

  use WebSockex
  require Logger

  @host "localhost"
  @port 9341

  def start_link do
    WebSockex.start_link("ws://#{@host}:#{@port}", __MODULE__, :no_state,
      extra_headers: [{"Host", "#{@host}:#{@port}"}]
    )
  end

  def run do
    suffix = UUID.uuid4() |> String.slice(0, 8)
    ids = build_ids(suffix)
    {:ok, pid} = start_link()
    send_add_slot(pid, ids)
    send_add_quad_mesh(pid, ids)
    send_add_pbs_metallic(pid, ids)
    send_add_mesh_renderer(pid, ids)
    send_update_mesh_renderer(pid, ids)
    send_update_material_color(pid, ids)
    :ok
  end

  def handle_connect(_conn, state) do
    Logger.info("ResoniteLink接続成功")
    {:ok, state}
  end

  def handle_cast({:send_text, message}, state) do
    {:reply, {:text, message}, state}
  end

  def handle_frame({:text, message}, state) do
    Logger.info("受信: #{message}")
    {:ok, state}
  end

  defp send_text(pid, message) do
    WebSockex.cast(pid, {:send_text, message})
    Process.sleep(150)
  end

  defp send_add_slot(pid, ids) do
    message = """
    {
      "$type": "addSlot",
      "data": {
        "id": "#{ids.slot_id}",
        "parent": { "$type": "reference", "targetId": "Root" },
        "name": { "$type": "string", "value": "RedSquareSample" },
        "position": { "$type": "float3", "value": { "x": 0, "y": 1.4, "z": 0.5 } },
        "scale": { "$type": "float3", "value": { "x": 0.7, "y": 0.7, "z": 0.7 } }
      }
    }
    """

    send_text(pid, message)
  end

  defp send_add_quad_mesh(pid, ids) do
    message = """
    {
      "$type": "addComponent",
      "containerSlotId": "#{ids.slot_id}",
      "data": {
        "id": "#{ids.mesh_id}",
        "componentType": "[FrooxEngine]FrooxEngine.QuadMesh"
      }
    }
    """

    send_text(pid, message)
  end

  defp send_add_pbs_metallic(pid, ids) do
    message = """
    {
      "$type": "addComponent",
      "containerSlotId": "#{ids.slot_id}",
      "data": {
        "id": "#{ids.material_id}",
        "componentType": "[FrooxEngine]FrooxEngine.PBS_Metallic"
      }
    }
    """

    send_text(pid, message)
  end

  defp send_add_mesh_renderer(pid, ids) do
    message = """
    {
      "$type": "addComponent",
      "containerSlotId": "#{ids.slot_id}",
      "data": {
        "id": "#{ids.renderer_id}",
        "componentType": "[FrooxEngine]FrooxEngine.MeshRenderer",
        "members": {
          "Mesh": { "$type": "reference", "targetId": "#{ids.mesh_id}" }
        }
      }
    }
    """

    send_text(pid, message)
  end

  defp send_update_mesh_renderer(pid, ids) do
    message = """
    {
      "$type": "updateComponent",
      "data": {
        "id": "#{ids.renderer_id}",
        "members": {
          "Materials": {
            "$type": "list",
            "elements": [{ "$type": "reference", "targetId": "#{ids.material_id}" }]
          }
        }
      }
    }
    """

    send_text(pid, message)
  end

  defp send_update_material_color(pid, ids) do
    message = """
    {
      "$type": "updateComponent",
      "data": {
        "id": "#{ids.material_id}",
        "members": {
          "AlbedoColor": {
            "$type": "colorX",
            "value": { "r": 1, "g": 0, "b": 0, "a": 1 }
          }
        }
      }
    }
    """

    send_text(pid, message)
  end

  defp build_ids(suffix) do
    %{
      slot_id: "sample_red_square_slot_#{suffix}",
      mesh_id: "sample_red_square_mesh_#{suffix}",
      material_id: "sample_red_square_mat_#{suffix}",
      renderer_id: "sample_red_square_renderer_#{suffix}"
    }
  end
end

RedSquareSample.run()

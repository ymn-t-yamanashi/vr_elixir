defmodule Sprint5CoreSample do
  @moduledoc """
  ResoniteLinkEx.Core の公開関数をすべて実行するサンプル。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Core
  @target_parent "ResoniteLinkEx"
  @timeout_ms 2_000
  @step_sleep_ms 2_000

  def run do
    {:ok, transport} = Client.start_link()
    ResoniteLinkEx.NameResolver.clear_resonite_link_ex_slot(transport)
    {:ok, ensured_parent_id} = ResoniteLinkEx.NameResolver.ensure_slot_id(transport, @target_parent)

    parent_id =
      case ResoniteLinkEx.NameResolver.resolve_slot_id(
             transport,
             @target_parent,
             parent_name: "Root"
           ) do
        {:ok, root_child_parent_id} -> root_child_parent_id
        {:error, :not_found} -> ensured_parent_id
        {:error, _reason} -> ensured_parent_id
      end

    name = "Sprint5Cube"
    position1 = %{"x" => 0.0, "y" => 1.0, "z" => 0.0}
    position2 = %{"x" => 0.2, "y" => 1.3, "z" => 0.1}

    IO.puts("[1/8] セッション情報を取得します（requestSessionData）")
    _ = call_core_over_transport(Core.request_session_data(:core_builder), transport)
    Process.sleep(@step_sleep_ms)

    slot_id = "Sprint5CoreSlot_#{System.system_time(:millisecond)}"

    IO.puts("[2/8] Cubeを作成します（addSlot） name=#{name}")
    _ =
      call_core_over_transport(
        Core.add_slot(:core_builder, %{
          parent_id: parent_id,
          name: name,
          position: position1,
          slot_id: slot_id
        }),
        transport
      )
    Process.sleep(@step_sleep_ms)

    IO.puts("[3/8] 作成したSlot情報を取得します（getSlot） slot_id=#{slot_id}")
    _ = call_core_over_transport(Core.get_slot(:core_builder, %{slot_id: slot_id}), transport)
    Process.sleep(@step_sleep_ms)

    IO.puts("[4/8] Cubeの位置を更新します（updateSlot）")
    _ =
      call_core_over_transport(
        Core.update_slot(:core_builder, %{slot_id: slot_id, position: position2}),
        transport
      )
    Process.sleep(@step_sleep_ms)

    component_id =
      case call_core_over_transport(
             Core.add_component(:core_builder, %{
               slot_id: slot_id,
               component_type: "FrooxEngine.DynamicVariableSpace"
             }),
             transport
           ) do
        {:ok, %{"entityId" => id}} when is_binary(id) -> id
        _ -> "Sprint5CoreComponent_#{System.system_time(:millisecond)}"
      end
    IO.puts("[5/8] Componentを追加します（addComponent）")
    Process.sleep(@step_sleep_ms)

    IO.puts("[6/8] Componentを更新します（updateComponent）")
    _ =
      call_core_over_transport(
        Core.update_component(:core_builder, %{
          component_id: component_id,
          members: %{"Enabled" => %{"$type" => "bool", "value" => true}}
        }),
        transport
      )
    Process.sleep(@step_sleep_ms)

    IO.puts("[7/8] Componentを削除します（removeComponent）")
    _ =
      call_core_over_transport(
        Core.remove_component(:core_builder, %{component_id: component_id}),
        transport
      )
    Process.sleep(@step_sleep_ms)

    IO.puts("[8/8] 最後にCubeを削除します（removeSlot）")
    _ = call_core_over_transport(Core.remove_slot(:core_builder, %{slot_id: slot_id}), transport)
    Process.sleep(@step_sleep_ms)

    :ok
  end

  defp call_core_over_transport({:ok, %{"messageId" => _} = request}, transport) do
    send_and_await(transport, request)
  end

  defp call_core_over_transport({:ok, %{type: type, payload: payload}}, transport) do
    with {:ok, request} <- build_wire_request(type, payload) do
      send_and_await(transport, request)
    end
  end

  defp call_core_over_transport({:error, reason}, _transport), do: {:error, reason}
  defp call_core_over_transport(_unknown, _transport), do: {:error, :invalid_request}

  defp send_and_await(transport, %{"messageId" => message_id} = request) do
    with {:ok, client_pid} <- Client.client_pid(transport),
         :ok <- Client.register_pending(client_pid, message_id, self()),
         :ok <- Client.send_json(transport, request) do
      await_response(client_pid, message_id, @timeout_ms)
    end
  end

  defp await_response(client_pid, message_id, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_response(client_pid, message_id, deadline)
  end

  defp do_await_response(client_pid, message_id, deadline) do
    case Client.last_response(client_pid) do
      %{"messageId" => ^message_id} = response ->
        {:ok, response}

      _other ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :request_timeout}
        else
          Process.sleep(20)
          do_await_response(client_pid, message_id, deadline)
        end
    end
  end

  defp build_wire_request("requestSessionData", payload) when is_map(payload) do
    {:ok, %{"messageId" => UUID.uuid4(), "$type" => "requestSessionData", "data" => payload}}
  end

  defp build_wire_request("addSlot", payload) do
    with {:ok, parent_id} <- fetch_required(payload, :parent_id),
         {:ok, name} <- fetch_required(payload, :name),
         {:ok, position} <- fetch_required(payload, :position),
         {:ok, slot_id} <- fetch_required(payload, :slot_id) do
      {:ok,
       %{
         "messageId" => UUID.uuid4(),
         "$type" => "addSlot",
         "data" => %{
           "id" => slot_id,
           "parent" => %{"$type" => "reference", "targetId" => parent_id},
           "name" => %{"$type" => "string", "value" => name},
           "position" => %{"$type" => "float3", "value" => position}
         }
       }}
    end
  end

  defp build_wire_request("getSlot", payload) do
    with {:ok, slot_id} <- fetch_required(payload, :slot_id) do
      {:ok, %{"messageId" => UUID.uuid4(), "$type" => "getSlot", "slotId" => slot_id}}
    end
  end

  defp build_wire_request("updateSlot", payload) do
    with {:ok, slot_id} <- fetch_required(payload, :slot_id),
         {:ok, position} <- fetch_required(payload, :position) do
      {:ok,
       %{
         "messageId" => UUID.uuid4(),
         "$type" => "updateSlot",
         "data" => %{
           "id" => slot_id,
           "position" => %{"$type" => "float3", "value" => position}
         }
       }}
    end
  end

  defp build_wire_request("addComponent", payload) do
    with {:ok, slot_id} <- fetch_required(payload, :slot_id),
         {:ok, component_type} <- fetch_required(payload, :component_type) do
      {:ok,
       %{
         "messageId" => UUID.uuid4(),
         "$type" => "addComponent",
         "data" => %{
           "id" => "Sprint5CoreComp_#{System.system_time(:millisecond)}",
           "containerSlotId" => slot_id,
           "type" => component_type
         }
       }}
    end
  end

  defp build_wire_request("updateComponent", payload) do
    with {:ok, component_id} <- fetch_required(payload, :component_id),
         {:ok, members} <- fetch_required(payload, :members) do
      {:ok,
       %{
         "messageId" => UUID.uuid4(),
         "$type" => "updateComponent",
         "data" => %{"id" => component_id, "members" => members}
       }}
    end
  end

  defp build_wire_request("removeComponent", payload) do
    with {:ok, component_id} <- fetch_required(payload, :component_id) do
      {:ok, %{"messageId" => UUID.uuid4(), "$type" => "removeComponent", "componentId" => component_id}}
    end
  end

  defp build_wire_request("removeSlot", payload) do
    with {:ok, slot_id} <- fetch_required(payload, :slot_id) do
      {:ok, %{"messageId" => UUID.uuid4(), "$type" => "removeSlot", "slotId" => slot_id}}
    end
  end

  defp build_wire_request(_type, _payload), do: {:error, :invalid_request}

  defp fetch_required(payload, key) when is_map(payload) do
    case Map.fetch(payload, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :invalid_request}
    end
  end
end

Sprint5CoreSample.run()

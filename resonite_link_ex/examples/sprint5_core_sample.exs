defmodule Sprint5CoreSample do
  @moduledoc """
  ResoniteLinkEx.Core の公開関数をすべて実行するサンプル。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Core
  @target_parent "ResoniteLinkEx"
  @timeout_ms 1_000
  @step_sleep_ms 1_000
  @retry_count 6

  def run do
    {:ok, transport} = Client.start_link()
    # parent_id = ensure_stable_parent_id(transport)

    ResoniteLinkEx.NameResolver.clear_resonite_link_ex_slot(transport)
    ResoniteLinkEx.NameResolver.ensure_slot_id(transport, "ResoniteLinkEx")

    name = "Sprint5Cube"
    position1 = %{"x" => 0.0, "y" => 1.0, "z" => 0.0}
    position2 = %{"x" => 0.2, "y" => 1.3, "z" => 0.1}

    IO.puts("[1/9] セッション情報を取得します（requestSessionData）")
    print_result(call_core_over_transport(Core.request_session_data(:core_builder), transport))
    Process.sleep(@step_sleep_ms)

    requested_slot_id = "Sprint5CoreSlot_#{System.system_time(:millisecond)}"

    IO.puts("[2/9] Cubeを作成します（addSlot） name=#{name}")

    add_slot_result =
      run_with_retry(fn ->
        call_core_over_transport(
          Core.add_slot(:core_builder, %{
            # parent_id: parent_id,
            name: name,
            position: position1,
            slot_id: requested_slot_id
          }),
          transport
        )
      end)

    # print_result(add_slot_result)
    Process.sleep(@step_sleep_ms)

    slot_id =
      case add_slot_result do
        {:ok, %{"entityId" => id}} when is_binary(id) and id != "" -> id
        _ -> requested_slot_id
      end

    IO.puts("[3/9] 作成したSlot情報を取得します（getSlot） slot_id=#{slot_id}")

    print_result(
      run_with_retry(fn ->
        call_core_over_transport(Core.get_slot(:core_builder, %{slot_id: slot_id}), transport)
      end)
    )

    Process.sleep(@step_sleep_ms)

    IO.puts("[4/9] Cubeの位置を更新します（updateSlot）")

    print_result(
      run_with_retry(fn ->
        call_core_over_transport(
          Core.update_slot(:core_builder, %{slot_id: slot_id, position: position2}),
          transport
        )
      end)
    )

    Process.sleep(@step_sleep_ms)

    mesh_add_result =
      call_core_over_transport(
        Core.add_component(:core_builder, %{
          slot_id: slot_id,
          component_type: "[FrooxEngine]FrooxEngine.BoxMesh"
        }),
        transport
      )

    mesh_component_id =
      case mesh_add_result do
        {:ok, %{"entityId" => id}} when is_binary(id) -> id
        _ -> "Sprint5CoreMeshComponent_#{System.system_time(:millisecond)}"
      end

    IO.puts("[5/9] BoxMeshを追加して図形を表示します（addComponent）")
    print_result(mesh_add_result)
    IO.puts("結果: component_id=#{mesh_component_id}")
    Process.sleep(@step_sleep_ms)

    renderer_add_result =
      call_core_over_transport(
        Core.add_component(:core_builder, %{
          slot_id: slot_id,
          component_type: "[FrooxEngine]FrooxEngine.MeshRenderer"
        }),
        transport
      )

    IO.puts("[6/9] MeshRendererを追加します（addComponent）")
    print_result(renderer_add_result)
    Process.sleep(@step_sleep_ms)

    component_id =
      case renderer_add_result do
        {:ok, %{"entityId" => id}} when is_binary(id) -> id
        _ -> mesh_component_id
      end

    IO.puts("[7/9] Componentを更新します（updateComponent）")

    print_result(
      call_core_over_transport(
        Core.update_component(:core_builder, %{
          component_id: component_id,
          members: %{"Enabled" => %{"$type" => "bool", "value" => true}}
        }),
        transport
      )
    )

    Process.sleep(@step_sleep_ms)

    temp_slot_id = "Sprint5CoreTemp_#{System.system_time(:millisecond)}"

    _ =
      run_with_retry(fn ->
        call_core_over_transport(
          Core.add_slot(:core_builder, %{
            # parent_id: parent_id,
            name: "Sprint5Temp",
            position: %{"x" => 0.0, "y" => 0.0, "z" => 0.0},
            slot_id: temp_slot_id
          }),
          transport
        )
      end)

    # temp_add_component_result =
    #   run_with_retry(fn ->
    #     call_core_over_transport(
    #       Core.add_component(:core_builder, %{
    #         slot_id: temp_slot_id,
    #         component_type: "[FrooxEngine]FrooxEngine.BoxMesh"
    #       }),
    #       transport
    #     )
    #   end)

    # temp_comp_id =
    #   case temp_add_component_result do
    #     {:ok, %{"entityId" => id}} when is_binary(id) and id != "" -> id
    #     _ -> nil
    #   end

    # IO.puts("[8/9] 一時Componentを削除します（removeComponent）")
    # if is_binary(temp_comp_id) do
    #   print_result(
    #     call_core_over_transport(
    #       Core.remove_component(:core_builder, %{component_id: temp_comp_id}),
    #       transport
    #     )
    #   )
    # else
    #   IO.puts("結果: success=false error=\"一時ComponentのID取得に失敗しました\"")
    # end
    # Process.sleep(@step_sleep_ms)

    # IO.puts("[9/9] 一時Slotを削除します（removeSlot）")
    # print_result(
    #   run_with_retry(fn ->
    #     call_core_over_transport(Core.remove_slot(:core_builder, %{slot_id: temp_slot_id}), transport)
    #   end)
    # )
    # Process.sleep(@step_sleep_ms)

    # :ok
  end

  defp ensure_stable_parent_id(transport) do
    _ = ResoniteLinkEx.NameResolver.clear_resonite_link_ex_slot(transport)
    Process.sleep(150)

    case find_root_child_id_by_name(transport, @target_parent) do
      {:ok, slot_id} ->
        slot_id

      {:error, _} ->
        slot_id = "sprint5_parent_#{System.system_time(:millisecond)}"

        _ =
          call_core_over_transport(
            Core.add_slot(:core_builder, %{
              parent_id: "Root",
              name: @target_parent,
              position: %{"x" => 0.0, "y" => 0.0, "z" => 0.0},
              slot_id: slot_id
            }),
            transport
          )

        Process.sleep(150)

        case find_root_child_id_by_name(transport, @target_parent) do
          {:ok, found} -> found
          {:error, _} -> slot_id
        end
    end
  end

  defp find_root_child_id_by_name(transport, name) do
    case call_core_over_transport(Core.get_slot(:core_builder, %{slot_id: "Root"}), transport) do
      {:ok, %{"success" => true, "data" => data}} when is_map(data) ->
        children = Map.get(data, "children", []) |> List.wrap()

        match =
          Enum.find(children, fn child ->
            (get_in(child, ["name", "value"]) || "") == name
          end)

        if is_map(match) and is_binary(match["id"]),
          do: {:ok, match["id"]},
          else: {:error, :not_found}

      _ ->
        {:error, :not_found}
    end
  end

  defp wait_slot_exists(_transport, _slot_id, 0), do: {:error, :not_found}

  defp wait_slot_exists(transport, slot_id, retry_left) do
    case call_core_over_transport(Core.get_slot(:core_builder, %{slot_id: slot_id}), transport) do
      {:ok, %{"success" => true}} ->
        :ok

      _ ->
        Process.sleep(50)
        wait_slot_exists(transport, slot_id, retry_left - 1)
    end
  end

  defp run_with_retry(fun), do: run_with_retry(fun, @retry_count)
  defp run_with_retry(fun, 0), do: fun.()

  defp run_with_retry(fun, retry_left) do
    result = fun.()

    case result do
      {:ok, %{"success" => true}} ->
        result

      {:ok, %{"success" => false, "errorInfo" => error}} when is_binary(error) ->
        if String.contains?(String.downcase(error), "not found") do
          Process.sleep(120)
          run_with_retry(fun, retry_left - 1)
        else
          result
        end

      {:error, :request_timeout} ->
        Process.sleep(120)
        run_with_retry(fun, retry_left - 1)

      _ ->
        result
    end
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
         "containerSlotId" => slot_id,
         "data" => %{
           "id" => "Sprint5CoreComp_#{System.system_time(:millisecond)}",
           "componentType" => component_type
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
      {:ok,
       %{"messageId" => UUID.uuid4(), "$type" => "removeComponent", "componentId" => component_id}}
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

  defp print_result({:ok, %{"success" => true}}), do: IO.puts("結果: success=true")

  defp print_result({:ok, %{"success" => false, "errorInfo" => error}}),
    do: IO.puts("結果: success=false error=#{inspect(error)}")

  defp print_result({:ok, _}), do: IO.puts("結果: ok")
  defp print_result({:error, reason}), do: IO.puts("結果: error=#{inspect(reason)}")
  defp print_result(_), do: IO.puts("結果: unknown")
end

Sprint5CoreSample.run()

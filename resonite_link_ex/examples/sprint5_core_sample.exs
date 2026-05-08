defmodule Sprint5CoreSample do
  @moduledoc """
  ResoniteLinkEx.Core を使って add/update/remove を行う最小サンプル。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Core
  @target_parent "ResoniteLinkEx"
  @timeout_ms 2_000

  def run do
    {:ok, transport} = Client.start_link()
    ResoniteLinkEx.NameResolver.clear_resonite_link_ex_slot(transport)
    {:ok, _parent_id} = ResoniteLinkEx.NameResolver.ensure_slot_id(transport, @target_parent)

    name = "Sprint5CoreCube_#{System.system_time(:millisecond)}"
    position1 = %{"x" => 0.0, "y" => 1.0, "z" => 0.0}
    position2 = %{"x" => 0.2, "y" => 1.3, "z" => 0.1}

    IO.puts("[1/4] requestSessionData")

    {:ok, session_res} =
      call_core_over_transport(transport, Core.request_session_data(:core_builder))

    IO.puts("session: #{inspect(Map.take(session_res, ["$type", "messageId"]))}")

    IO.puts("[2/4] addSlot name=#{name}")
    slot_id = "Sprint5CoreSlot_#{System.system_time(:millisecond)}"

    {:ok, add_res} =
      call_core_over_transport(
        transport,
        Core.add_slot(:core_builder, %{
          parent_id: "Root",
          name: name,
          position: position1,
          slot_id: slot_id
        })
      )

    IO.puts("addSlot response: #{inspect(add_res)}")
    IO.puts("addSlot result slot_id=#{slot_id}")

    IO.puts("[3/4] updateSlot")

    {:ok, update_res} =
      call_core_over_transport(
        transport,
        Core.update_slot(:core_builder, %{slot_id: slot_id, position: position2})
      )

    IO.puts("updateSlot: #{inspect(Map.take(update_res, ["$type", "messageId"]))}")

    IO.puts("[4/4] removeSlot")

    {:ok, remove_res} =
      call_core_over_transport(
        transport,
        Core.remove_slot(:core_builder, %{slot_id: slot_id})
      )

    IO.puts("removeSlot: #{inspect(Map.take(remove_res, ["$type", "messageId"]))}")
    :ok
  end

  defp call_core_over_transport(transport, {:ok, %{"messageId" => _} = request}) do
    send_and_await(transport, request)
  end

  defp call_core_over_transport(transport, {:ok, %{type: type, payload: payload}}) do
    with {:ok, request} <- build_wire_request(type, payload) do
      send_and_await(transport, request)
    end
  end

  defp call_core_over_transport(_transport, {:error, reason}), do: {:error, reason}
  defp call_core_over_transport(_transport, _unknown), do: {:error, :invalid_request}

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

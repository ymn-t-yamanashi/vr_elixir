defmodule ResoniteLinkExTest do
  use ExUnit.Case, async: true
  doctest ResoniteLinkEx

  test "start_client/1 はクライアントを起動できる" do
    assert {:ok, pid} = ResoniteLinkEx.start_client()
    assert is_pid(pid)
    assert Process.alive?(pid)
  end

  test "call/3 は Client.call/3 を委譲する" do
    assert {:ok, pid} = ResoniteLinkEx.start_client()
    payload = %{parent_id: "Root", name: "BoxA"}

    assert {:ok, %{"$type" => "addSlot", "data" => ^payload, "messageId" => _message_id}} =
             ResoniteLinkEx.call(pid, "addSlot", payload)
  end

  test "receive_response/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = ResoniteLinkEx.receive_response(:not_pid, %{})
  end

  test "get_slot/2 は getSlot 呼び出しを委譲する" do
    assert {:ok, pid} = ResoniteLinkEx.start_client()

    assert {:ok,
            %{"$type" => "getSlot", "data" => %{slot_id: "SlotA"}, "messageId" => _message_id}} =
             ResoniteLinkEx.get_slot(pid, "SlotA")
  end

  test "get_slot/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = ResoniteLinkEx.get_slot(self(), :bad)
  end

  test "move_slot_by_name/4 は Objects.move_slot_by_name/4 を委譲する" do
    assert {:ok, pid} = ResoniteLinkEx.start_client()
    resolver = fn _client, _name, _opts -> {:ok, "SlotA"} end
    position = %{"x" => 0, "y" => 1, "z" => 2}

    assert {:ok, %{"$type" => "updateSlot", "data" => %{slot_id: "SlotA", position: ^position}}} =
             ResoniteLinkEx.move_slot_by_name(pid, "CubeA", position,
               resolve_slot_id_fun: resolver
             )
  end

  test "move_slot_by_name/3 はデフォルト opts で委譲する" do
    assert {:ok, pid} = ResoniteLinkEx.start_client()
    position = %{"x" => 0, "y" => 1, "z" => 2}

    assert {:error, :invalid_request} = ResoniteLinkEx.move_slot_by_name(pid, "CubeA", position)
  end

  test "delete_slot_by_name/3 は Objects.delete_slot_by_name/3 を委譲する" do
    assert {:ok, pid} = ResoniteLinkEx.start_client()
    resolver = fn _client, _name, _opts -> {:ok, "SlotA"} end

    assert {:ok, %{"$type" => "removeSlot", "data" => %{slot_id: "SlotA"}}} =
             ResoniteLinkEx.delete_slot_by_name(pid, "CubeA", resolve_slot_id_fun: resolver)
  end

  test "delete_slot_by_name/2 はデフォルト opts で委譲する" do
    assert {:ok, pid} = ResoniteLinkEx.start_client()
    assert {:error, :invalid_request} = ResoniteLinkEx.delete_slot_by_name(pid, "CubeA")
  end

  test "move_slot/3 と delete_slot/2 は互換APIを委譲する" do
    assert {:ok, pid} = ResoniteLinkEx.start_client()
    position = %{"x" => 0, "y" => 1, "z" => 2}

    assert {:ok, %{"$type" => "updateSlot", "data" => %{slot_id: "SlotA", position: ^position}}} =
             ResoniteLinkEx.move_slot(pid, "SlotA", position)

    assert {:ok, %{"$type" => "removeSlot", "data" => %{slot_id: "SlotA"}}} =
             ResoniteLinkEx.delete_slot(pid, "SlotA")
  end

  test "spawn_shape/3 は Shapes.spawn_shape/3 を委譲する" do
    send_fun = fn _transport_pid, _payload -> :ok end

    assert {:ok, ids} =
             ResoniteLinkEx.spawn_shape(self(), :quad,
               name: "QuadA",
               send_fun: send_fun,
               client_pid: nil
             )

    assert is_binary(ids.slot_id)
  end

  test "find_resonite_link_port/1 は PortDiscovery へ委譲する" do
    output =
      "LISTEN 0      500        127.0.0.1:55555      0.0.0.0:*    users:((\"dotnet\",pid=1,fd=1))"

    fake_cmd = fn "ss", ["-ltnp"] -> {output, 0} end

    assert {:ok, 55_555} = ResoniteLinkEx.find_resonite_link_port(fake_cmd)
  end

  test "find_resonite_link_port/0 は結果タプルを返す" do
    result = ResoniteLinkEx.find_resonite_link_port()
    assert is_tuple(result)
    assert tuple_size(result) == 2
    assert elem(result, 0) in [:ok, :error]
  end
end

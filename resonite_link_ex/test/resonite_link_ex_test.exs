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

  test "spawn_shape/3 は Shapes.spawn_shape/3 を委譲する" do
    send_fun = fn _transport_pid, _payload -> :ok end

    assert {:ok, ids} =
             ResoniteLinkEx.spawn_shape(self(), :quad, name: "QuadA", send_fun: send_fun)

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

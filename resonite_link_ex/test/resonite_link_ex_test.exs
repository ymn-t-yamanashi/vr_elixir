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
end

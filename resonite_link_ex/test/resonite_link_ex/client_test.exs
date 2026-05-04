defmodule ResoniteLinkEx.ClientTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Client

  test "start_link/1 はクライアントプロセスを起動できる" do
    assert {:ok, pid} = Client.start_link([])
    assert is_pid(pid)
    assert Process.alive?(pid)
    assert Client.connected?(pid)

    Process.exit(pid, :normal)
  end

  test "connected?/1 は停止済みプロセスで false を返す" do
    assert {:ok, pid} = Client.start_link([])
    Process.unlink(pid)
    Process.exit(pid, :shutdown)
    Process.sleep(10)

    refute Client.connected?(pid)
  end

  test "connected?/1 は pid 以外で false を返す" do
    refute Client.connected?(:not_pid)
  end

  test "send_command/3 は接続中なら Scene.call/3 の結果を返す" do
    assert {:ok, pid} = Client.start_link([])
    payload = %{parent_id: "Root", name: "BoxA"}

    assert {:ok, %{type: "addSlot", payload: ^payload}} =
             Client.send_command(pid, "addSlot", payload)
  end

  test "send_command/3 は未接続なら not_connected を返す" do
    assert {:ok, pid} = Client.start_link([])
    Process.unlink(pid)
    Process.exit(pid, :shutdown)
    Process.sleep(10)

    assert {:error, :not_connected} = Client.send_command(pid, "requestSessionData", %{})
  end

  test "request/3 は接続中なら encode_request の結果を返す" do
    assert {:ok, pid} = Client.start_link([])
    payload = %{parent_id: "Root", name: "BoxA"}

    assert {:ok, %{"$type" => "addSlot", "data" => ^payload}} =
             Client.request(pid, "addSlot", payload)
  end

  test "request/3 は未接続なら not_connected を返す" do
    assert {:ok, pid} = Client.start_link([])
    Process.unlink(pid)
    Process.exit(pid, :shutdown)
    Process.sleep(10)

    assert {:error, :not_connected} = Client.request(pid, "requestSessionData", %{})
  end

  test "request/4 は不正な timeout で invalid_request を返す" do
    assert {:ok, pid} = Client.start_link([])
    assert {:error, :invalid_request} = Client.request(pid, "requestSessionData", %{}, 0)
  end

  test "request/4 は接続中かつ正の timeout で encode_request の結果を返す" do
    assert {:ok, pid} = Client.start_link([])
    payload = %{parent_id: "Root", name: "BoxA"}

    assert {:ok, %{"$type" => "addSlot", "data" => ^payload}} =
             Client.request(pid, "addSlot", payload, 1000)
  end

  test "request/4 は timeout が整数以外で invalid_request を返す" do
    assert {:ok, pid} = Client.start_link([])
    assert {:error, :invalid_request} = Client.request(pid, "requestSessionData", %{}, "1000")
  end

  test "request/5 は encode 処理が timeout 超過なら request_timeout を返す" do
    assert {:ok, pid} = Client.start_link([])

    slow_encode = fn _type, _payload ->
      Process.sleep(20)
      {:ok, %{"$type" => "dummy", "data" => %{}}}
    end

    assert {:error, :request_timeout} =
             Client.request(pid, "requestSessionData", %{}, 1, slow_encode)
  end

  test "request/5 は未接続なら not_connected を返す" do
    assert {:error, :not_connected} =
             Client.request(:not_pid, "requestSessionData", %{}, 1000, fn _type, _payload ->
               {:ok, %{"$type" => "dummy", "data" => %{}}}
             end)
  end

  test "request/5 は接続中なら指定 encode 関数の結果を返す" do
    assert {:ok, pid} = Client.start_link([])

    assert {:ok, %{"$type" => "requestSessionData", "data" => %{k: "v"}}} =
             Client.request(pid, "requestSessionData", %{k: "v"}, 1000, fn type, payload ->
               {:ok, %{"$type" => type, "data" => payload}}
             end)
  end

  test "request/5 は不正な timeout で invalid_request を返す" do
    assert {:ok, pid} = Client.start_link([])

    assert {:error, :invalid_request} =
             Client.request(pid, "requestSessionData", %{}, 0, fn _type, _payload ->
               {:ok, %{}}
             end)
  end
end

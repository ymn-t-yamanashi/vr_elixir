defmodule ResoniteLinkEx.ClientTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

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

  test "call/3 は接続中なら request の結果を返す" do
    assert {:ok, pid} = Client.start_link([])
    payload = %{parent_id: "Root", name: "BoxA"}

    assert {:ok, %{"messageId" => _message_id, "$type" => "addSlot", "data" => ^payload}} =
             Client.call(pid, "addSlot", payload)
  end

  test "call/3 は未接続なら not_connected を返す" do
    assert {:ok, pid} = Client.start_link([])
    Process.unlink(pid)
    Process.exit(pid, :shutdown)
    Process.sleep(10)

    assert {:error, :not_connected} = Client.call(pid, "requestSessionData", %{})
  end

  test "request/3 は接続中なら encode_request の結果を返す" do
    assert {:ok, pid} = Client.start_link([])
    payload = %{parent_id: "Root", name: "BoxA"}

    assert {:ok, %{"messageId" => message_id, "$type" => "addSlot", "data" => ^payload}} =
             Client.request(pid, "addSlot", payload)

    assert message_id =~
             ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
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

    assert {:ok, %{"messageId" => message_id, "$type" => "addSlot", "data" => ^payload}} =
             Client.request(pid, "addSlot", payload, 1000)

    assert message_id =~
             ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
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
    assert 0 = Client.pending_count(pid)

    assert {:ok, %{"$type" => "requestSessionData", "data" => %{k: "v"}}} =
             Client.request(pid, "requestSessionData", %{k: "v"}, 1000, fn type, payload ->
               {:ok,
                %{
                  "messageId" => "f47ac10b-58cc-4372-a567-0e02b2c3d479",
                  "$type" => type,
                  "data" => payload
                }}
             end)

    assert 1 = Client.pending_count(pid)
  end

  test "request/5 は不正な timeout で invalid_request を返す" do
    assert {:ok, pid} = Client.start_link([])

    assert {:error, :invalid_request} =
             Client.request(pid, "requestSessionData", %{}, 0, fn _type, _payload ->
               {:ok, %{}}
             end)
  end

  test "register_pending/3 と resolve_pending/2 は messageId で対応付けできる" do
    assert {:ok, pid} = Client.start_link([])
    waiter_pid = self()
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"

    assert :ok = Client.register_pending(pid, message_id, waiter_pid)
    assert 1 = Client.pending_count(pid)
    assert {:ok, ^waiter_pid} = Client.resolve_pending(pid, message_id)
    assert 0 = Client.pending_count(pid)
  end

  test "resolve_pending/2 は未知の messageId で unknown_message_id を返す" do
    assert {:ok, pid} = Client.start_link([])
    assert {:error, :unknown_message_id} = Client.resolve_pending(pid, "unknown-id")
  end

  test "resolve_pending/2 は不正引数で unknown_message_id を返す" do
    assert {:error, :unknown_message_id} = Client.resolve_pending(:not_pid, "id")
    assert {:error, :unknown_message_id} = Client.resolve_pending(self(), :not_binary)
  end

  test "register_pending/3 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.register_pending(:not_pid, "id", self())
    assert {:error, :invalid_request} = Client.register_pending(self(), :not_binary, self())
    assert {:error, :invalid_request} = Client.register_pending(self(), "id", :not_pid)
  end

  test "pending_count/1 は pid 以外で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.pending_count(:not_pid)
  end

  test "request/5 は messageId なしの結果なら pending を増やさない" do
    assert {:ok, pid} = Client.start_link([])
    assert 0 = Client.pending_count(pid)

    assert {:ok, %{"$type" => "requestSessionData", "data" => %{}}} =
             Client.request(pid, "requestSessionData", %{}, 1000, fn _type, _payload ->
               {:ok, %{"$type" => "requestSessionData", "data" => %{}}}
             end)

    assert 0 = Client.pending_count(pid)
  end

  test "receive_response/2 は既知 messageId の pending を解決して削除する" do
    assert {:ok, pid} = Client.start_link([])
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    response = %{"messageId" => message_id, "status" => "ok"}
    assert :ok = Client.register_pending(pid, message_id, self())
    assert 1 = Client.pending_count(pid)
    assert :ok = Client.receive_response(pid, response)
    assert 0 = Client.pending_count(pid)
    assert ^response = Client.last_response(pid)
  end

  test "receive_response/2 は未知 messageId で warn ログのみ出力する" do
    assert {:ok, pid} = Client.start_link([])

    log =
      capture_log(fn ->
        assert :ok =
                 Client.receive_response(pid, %{"messageId" => "unknown-id", "status" => "ok"})
      end)

    assert log =~ "event=unknown_message_id"
    assert log =~ "message_id=unknown-id"
  end

  test "receive_response/2 は decode 失敗で decode_error を返す" do
    assert {:ok, pid} = Client.start_link([])
    assert {:error, :decode_error} = Client.receive_response(pid, %{"status" => "ok"})
  end

  test "receive_response/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.receive_response(:not_pid, %{"messageId" => "id"})
    assert {:error, :invalid_request} = Client.receive_response(self(), :not_map)
  end

  test "last_response/1 は未受信時に nil を返す" do
    assert {:ok, pid} = Client.start_link([])
    assert nil == Client.last_response(pid)
  end

  test "last_response/1 は pid 以外で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.last_response(:not_pid)
  end

  test "session_ready?/1 は初期状態で false を返す" do
    assert {:ok, pid} = Client.start_link([])
    refute Client.session_ready?(pid)
  end

  test "session_ready?/1 は requestSessionData 成功応答で true になる" do
    assert {:ok, pid} = Client.start_link([])
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    assert :ok = Client.register_pending(pid, message_id, self())
    refute Client.session_ready?(pid)

    assert :ok =
             Client.receive_response(pid, %{
               "messageId" => message_id,
               "$type" => "requestSessionData",
               "status" => "ok"
             })

    assert Client.session_ready?(pid)
  end

  test "session_ready?/1 は他応答では true にならない" do
    assert {:ok, pid} = Client.start_link([])
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    assert :ok = Client.register_pending(pid, message_id, self())

    assert :ok =
             Client.receive_response(pid, %{
               "messageId" => message_id,
               "$type" => "addSlot",
               "status" => "ok"
             })

    refute Client.session_ready?(pid)
  end

  test "session_ready?/1 は pid 以外で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.session_ready?(:not_pid)
  end

  test "handle_disconnect/2 は close_frame で session_ready を false に戻し pending を空にする" do
    assert {:ok, pid} = Client.start_link([])
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    assert :ok = Client.register_pending(pid, message_id, self())

    assert :ok =
             Client.receive_response(pid, %{
               "messageId" => message_id,
               "$type" => "requestSessionData",
               "status" => "ok"
             })

    assert Client.session_ready?(pid)
    assert 0 = Client.pending_count(pid)
    assert :ok = Client.register_pending(pid, "f47ac10b-58cc-4372-a567-0e02b2c3d470", self())
    assert 1 = Client.pending_count(pid)

    assert :ok = Client.handle_disconnect(pid, :close_frame)
    refute Client.session_ready?(pid)
    assert 0 = Client.pending_count(pid)
  end

  test "handle_disconnect/2 は tcp_error で受け付ける" do
    assert {:ok, pid} = Client.start_link([])
    assert :ok = Client.handle_disconnect(pid, :tcp_error)
  end

  test "handle_disconnect/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.handle_disconnect(:not_pid, :close_frame)
    assert {:error, :invalid_request} = Client.handle_disconnect(self(), :pong_timeout)
  end
end

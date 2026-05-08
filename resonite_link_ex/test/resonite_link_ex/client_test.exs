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

  test "call/3 は再接続中なら not_connected を返す" do
    assert {:ok, pid} = Client.start_link([])
    assert :ok = Client.set_reconnecting(pid, true)
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

  test "session_ready?/1 は sessionData 成功応答で true になる" do
    assert {:ok, pid} = Client.start_link([])
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    assert :ok = Client.register_pending(pid, message_id, self())
    refute Client.session_ready?(pid)

    assert :ok =
             Client.receive_response(pid, %{
               "messageId" => message_id,
               "$type" => "sessionData",
               "success" => true
             })

    assert Client.session_ready?(pid)
  end

  test "sessionData 成功応答で reconnecting は false に戻る" do
    assert {:ok, pid} = Client.start_link([])
    assert :ok = Client.set_reconnecting(pid, true)
    assert Client.reconnecting?(pid)
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    assert :ok = Client.register_pending(pid, message_id, self())

    assert :ok =
             Client.receive_response(pid, %{
               "messageId" => message_id,
               "$type" => "sessionData",
               "success" => true
             })

    refute Client.reconnecting?(pid)
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

  test "reconnecting?/1 は初期状態で false を返す" do
    assert {:ok, pid} = Client.start_link([])
    refute Client.reconnecting?(pid)
  end

  test "set_reconnecting/2 で再接続状態を更新できる" do
    assert {:ok, pid} = Client.start_link([])
    assert :ok = Client.set_reconnecting(pid, true)
    assert Client.reconnecting?(pid)
    assert :ok = Client.set_reconnecting(pid, false)
    refute Client.reconnecting?(pid)
  end

  test "reconnecting?/1 と set_reconnecting/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.reconnecting?(:not_pid)
    assert {:error, :invalid_request} = Client.set_reconnecting(:not_pid, true)
    assert {:error, :invalid_request} = Client.set_reconnecting(self(), :not_bool)
  end

  test "handle_disconnect/2 は close_frame で session_ready を false に戻し pending を空にする" do
    assert {:ok, pid} = Client.start_link([])
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    assert :ok = Client.register_pending(pid, message_id, self())

    assert :ok =
             Client.receive_response(pid, %{
               "messageId" => message_id,
               "$type" => "sessionData",
               "success" => true
             })

    assert Client.session_ready?(pid)
    assert 0 = Client.pending_count(pid)
    assert :ok = Client.register_pending(pid, "f47ac10b-58cc-4372-a567-0e02b2c3d470", self())
    assert 1 = Client.pending_count(pid)

    assert :ok = Client.handle_disconnect(pid, :close_frame)
    refute Client.session_ready?(pid)
    assert Client.reconnecting?(pid)
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

  test "build_url/1 は既定値で URL を生成する" do
    assert "ws://localhost:12512" == Client.build_url([])
  end

  test "build_url/1 は host/port/path 指定を反映する" do
    assert "ws://example.local:9999/ws" ==
             Client.build_url(host: "example.local", port: 9999, path: "ws")
  end

  test "build_url/1 は空 path を許可する" do
    assert "ws://example.local:9999" ==
             Client.build_url(host: "example.local", port: 9999, path: "")
  end

  test "build_url/1 は先頭スラッシュ付き path をそのまま使う" do
    assert "ws://example.local:9999/ws" ==
             Client.build_url(host: "example.local", port: 9999, path: "/ws")
  end

  test "encode_outbound/1 は map を JSON へ変換する" do
    assert {:ok, json} = Client.encode_outbound(%{"k" => "v"})
    assert is_binary(json)
  end

  test "encode_outbound/1 は map 以外を invalid_request で拒否する" do
    assert {:error, :invalid_request} = Client.encode_outbound(:not_map)
  end

  test "decode_inbound/1 は JSON 文字列を map に変換する" do
    assert {:ok, %{"k" => "v"}} = Client.decode_inbound(~s({"k":"v"}))
  end

  test "decode_inbound/1 は不正 JSON を decode_error で返す" do
    assert {:error, :decode_error} = Client.decode_inbound("{")
  end

  test "decode_inbound/1 は文字列以外を decode_error で返す" do
    assert {:error, :decode_error} = Client.decode_inbound(:not_binary)
  end

  test "map_disconnect_reason/1 は close_frame/tcp_error に正規化する" do
    assert :close_frame = Client.map_disconnect_reason({:remote, 1000, "ok"})
    assert :close_frame = Client.map_disconnect_reason({:local, :normal})
    assert :tcp_error = Client.map_disconnect_reason({:error, :econnrefused})
    assert :tcp_error = Client.map_disconnect_reason(:unknown)
  end

  test "start_link/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.start_link(:not_pid, [])
  end

  test "start_link/2 は接続不可でもエラータプルを返す" do
    assert {:ok, client} = Client.start_link([])
    assert {:error, _reason} = Client.start_link(client, host: "127.0.0.1", port: 1, path: "/")
  end

  test "start_link/2 はローカルWSサーバーへ接続できる" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])

    assert {:ok, transport} =
             Client.start_link(client, host: "localhost", port: port, path: "")

    assert is_pid(transport)
    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "start_link/1 は接続オプションのみでローカルWSサーバーへ接続できる" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, transport} = Client.start_link(host: "localhost", port: port, path: "")

    assert is_pid(transport)
    assert {:ok, client} = Client.client_pid(transport)
    assert is_pid(client)
    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "send_json/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.send_json(:not_pid, %{})
    assert {:error, :invalid_request} = Client.send_json(self(), :not_map)
  end

  test "client_pid/1 はトランスポートから client pid を取得できる" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])

    assert {:ok, transport} =
             Client.start_link(client, host: "localhost", port: port, path: "")

    assert {:ok, ^client} = Client.client_pid(transport)
    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "client_pid/1 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Client.client_pid(:not_pid)
  end

  test "client_pid/1 は self 指定を invalid_request で拒否する" do
    assert {:error, :invalid_request} = Client.client_pid(self())
  end

  test "client_pid/1 は state に client_pid が無い場合 invalid_request を返す" do
    {:ok, pid} = Agent.start_link(fn -> %{client_pid: "not_pid"} end)
    assert {:error, :invalid_request} = Client.client_pid(pid)
    Agent.stop(pid)
  end

  test "send_json/2 は有効payloadを送信できる" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])

    assert {:ok, transport} =
             Client.start_link(client, host: "localhost", port: port, path: "")

    assert :ok = Client.send_json(transport, %{"$type" => "requestSessionData", "data" => %{}})
    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "send_json/2 はJSON化できないpayloadで invalid_request を返す" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])

    assert {:ok, transport} =
             Client.start_link(client, host: "localhost", port: port, path: "")

    assert {:error, :invalid_request} = Client.send_json(transport, %{"bad" => self()})
    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "handle_connect/2 は初期要求送信用 cast を予約して :ok を返す" do
    assert {:ok, client} = Client.start_link([])
    assert :ok = Client.set_reconnecting(client, true)
    state = %{client_pid: client, opts: []}

    assert {:ok, ^state} = Client.handle_connect(:connected, state)
    refute Client.reconnecting?(client)
  end

  test "handle_disconnect/2 は Client に切断通知する" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}

    assert {:ok, ^state} = Client.handle_disconnect({:error, :econnrefused}, state)
    assert Client.reconnecting?(client)
  end

  test "handle_cast/2 は初期要求送信を text frame に変換し pending 登録する" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}

    assert {:reply, {:text, json}, ^state} =
             Client.handle_cast(:send_initial_session_request, state)

    assert is_binary(json)
    assert 1 = Client.pending_count(client)
  end

  test "handle_cast/2 は send_text をそのまま text frame で返す" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}

    assert {:reply, {:text, "hello"}, ^state} =
             Client.handle_cast({:send_text, "hello"}, state)
  end

  test "handle_frame/2 は text JSON を Client へ連携する" do
    assert {:ok, client} = Client.start_link([])
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    state = %{client_pid: client, opts: []}
    assert :ok = Client.register_pending(client, message_id, self())

    json = "{\"sourceMessageId\":\"#{message_id}\",\"$type\":\"sessionData\",\"success\":true}"
    assert {:ok, ^state} = Client.handle_frame({:text, json}, state)
    assert Client.session_ready?(client)
  end

  test "handle_frame/2 は不正 JSON でも継続できる" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}
    assert {:ok, ^state} = Client.handle_frame({:text, "{"}, state)
  end

  test "handle_frame/2 は text 以外フレームを無視する" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}
    assert {:ok, ^state} = Client.handle_frame({:binary, <<1, 2>>}, state)
  end

  defp start_ws_mock_server do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true])

    {:ok, port} = :inet.port(listen_socket)

    pid =
      spawn_link(fn ->
        {:ok, socket} = :gen_tcp.accept(listen_socket)
        {:ok, request} = :gen_tcp.recv(socket, 0, 1_000)
        key = extract_ws_key(request)
        accept = ws_accept(key)

        response =
          "HTTP/1.1 101 Switching Protocols\r\n" <>
            "Upgrade: websocket\r\n" <>
            "Connection: Upgrade\r\n" <>
            "Sec-WebSocket-Accept: #{accept}\r\n\r\n"

        :ok = :gen_tcp.send(socket, response)
        Process.sleep(1_000)
        :gen_tcp.close(socket)
        :gen_tcp.close(listen_socket)
      end)

    {pid, port}
  end

  defp extract_ws_key(request) do
    request
    |> String.split("\r\n")
    |> Enum.find_value(fn line ->
      case String.split(line, ": ", parts: 2) do
        ["Sec-WebSocket-Key", key] -> key
        _other -> nil
      end
    end)
  end

  defp ws_accept(key) do
    :crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
    |> Base.encode64()
  end
end

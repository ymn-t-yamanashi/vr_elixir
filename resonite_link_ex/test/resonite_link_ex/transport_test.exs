defmodule ResoniteLinkEx.TransportTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Transport

  test "build_url/1 は既定値で URL を生成する" do
    assert "ws://localhost:12512" == Transport.build_url([])
  end

  test "build_url/1 は host/port/path 指定を反映する" do
    assert "ws://example.local:9999/ws" ==
             Transport.build_url(host: "example.local", port: 9999, path: "ws")
  end

  test "build_url/1 は空 path を許可する" do
    assert "ws://example.local:9999" ==
             Transport.build_url(host: "example.local", port: 9999, path: "")
  end

  test "build_url/1 は先頭スラッシュ付き path をそのまま使う" do
    assert "ws://example.local:9999/ws" ==
             Transport.build_url(host: "example.local", port: 9999, path: "/ws")
  end

  test "encode_outbound/1 は map を JSON へ変換する" do
    assert {:ok, json} = Transport.encode_outbound(%{"k" => "v"})
    assert is_binary(json)
  end

  test "encode_outbound/1 は map 以外を invalid_request で拒否する" do
    assert {:error, :invalid_request} = Transport.encode_outbound(:not_map)
  end

  test "decode_inbound/1 は JSON 文字列を map に変換する" do
    assert {:ok, %{"k" => "v"}} = Transport.decode_inbound(~s({"k":"v"}))
  end

  test "decode_inbound/1 は不正 JSON を decode_error で返す" do
    assert {:error, :decode_error} = Transport.decode_inbound("{")
  end

  test "decode_inbound/1 は文字列以外を decode_error で返す" do
    assert {:error, :decode_error} = Transport.decode_inbound(:not_binary)
  end

  test "map_disconnect_reason/1 は close_frame/tcp_error に正規化する" do
    assert :close_frame = Transport.map_disconnect_reason({:remote, 1000, "ok"})
    assert :close_frame = Transport.map_disconnect_reason({:local, :normal})
    assert :tcp_error = Transport.map_disconnect_reason({:error, :econnrefused})
    assert :tcp_error = Transport.map_disconnect_reason(:unknown)
  end

  test "start_link/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Transport.start_link(:not_pid, [])
  end

  test "start_link/2 は接続不可でもエラータプルを返す" do
    assert {:ok, client} = Client.start_link([])
    assert {:error, _reason} = Transport.start_link(client, host: "127.0.0.1", port: 1, path: "/")
  end

  test "start_link/2 はローカルWSサーバーへ接続できる" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])
    assert {:ok, transport} = Transport.start_link(client, host: "localhost", port: port, path: "")
    assert is_pid(transport)
    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "send_json/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = Transport.send_json(:not_pid, %{})
    assert {:error, :invalid_request} = Transport.send_json(self(), :not_map)
  end

  test "send_json/2 は有効payloadを送信できる" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])
    assert {:ok, transport} = Transport.start_link(client, host: "localhost", port: port, path: "")
    assert :ok = Transport.send_json(transport, %{"$type" => "requestSessionData", "data" => %{}})
    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "send_json/2 はJSON化できないpayloadで invalid_request を返す" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])
    assert {:ok, transport} = Transport.start_link(client, host: "localhost", port: port, path: "")
    assert {:error, :invalid_request} = Transport.send_json(transport, %{"bad" => self()})
    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "handle_connect/2 は初期要求送信用 cast を予約して :ok を返す" do
    assert {:ok, client} = Client.start_link([])
    assert :ok = Client.set_reconnecting(client, true)
    state = %{client_pid: client, opts: []}

    assert {:ok, ^state} = Transport.handle_connect(:connected, state)
    refute Client.reconnecting?(client)
  end

  test "handle_disconnect/2 は Client に切断通知する" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}

    assert {:ok, ^state} = Transport.handle_disconnect({:error, :econnrefused}, state)
    assert Client.reconnecting?(client)
  end

  test "handle_cast/2 は初期要求送信を text frame に変換し pending 登録する" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}

    assert {:reply, {:text, json}, ^state} =
             Transport.handle_cast(:send_initial_session_request, state)

    assert is_binary(json)
    assert 1 = Client.pending_count(client)
  end

  test "handle_cast/2 は send_text をそのまま text frame で返す" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}
    assert {:reply, {:text, "hello"}, ^state} = Transport.handle_cast({:send_text, "hello"}, state)
  end

  test "handle_frame/2 は text JSON を Client へ連携する" do
    assert {:ok, client} = Client.start_link([])
    message_id = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
    state = %{client_pid: client, opts: []}
    assert :ok = Client.register_pending(client, message_id, self())

    json = "{\"sourceMessageId\":\"#{message_id}\",\"$type\":\"sessionData\",\"success\":true}"
    assert {:ok, ^state} = Transport.handle_frame({:text, json}, state)
    assert Client.session_ready?(client)
  end

  test "handle_frame/2 は不正 JSON でも継続できる" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}
    assert {:ok, ^state} = Transport.handle_frame({:text, "{"}, state)
  end

  test "handle_frame/2 は text 以外フレームを無視する" do
    assert {:ok, client} = Client.start_link([])
    state = %{client_pid: client, opts: []}
    assert {:ok, ^state} = Transport.handle_frame({:binary, <<1, 2>>}, state)
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

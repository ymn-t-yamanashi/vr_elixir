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
end

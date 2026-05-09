defmodule ResoniteLinkEx.NameResolverTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.NameResolver

  test "resolve_slot_id/3 は一意な name を解決できる" do
    find_slots_fun = fn _client, "CubeA", _opts ->
      {:ok, [%{slot_id: "slot_a", name: "CubeA"}]}
    end

    get_slot_fun = fn _client, "slot_a" ->
      {:ok, %{type: "getSlot", payload: %{slot_id: "slot_a"}}}
    end

    assert {:ok, "slot_a"} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               find_slots_fun: find_slots_fun,
               get_slot_fun: get_slot_fun
             )
  end

  test "resolve_slot_id/2 はデフォルト opts で invalid_request を返す" do
    assert {:error, :invalid_request} = NameResolver.resolve_slot_id(:client, "CubeA")
  end

  test "resolve_slot_id/3 は候補なしで not_found を返す" do
    find_slots_fun = fn _client, _name, _opts -> {:ok, []} end

    assert {:error, :not_found} =
             NameResolver.resolve_slot_id(:client, "Missing", find_slots_fun: find_slots_fun)
  end

  test "resolve_slot_id/3 は同名複数で parent_name 未指定なら ambiguous_name を返す" do
    slots = [%{slot_id: "slot_a", name: "CubeA"}, %{slot_id: "slot_b", name: "CubeA"}]
    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    assert {:error, :ambiguous_name} =
             NameResolver.resolve_slot_id(:client, "CubeA", find_slots_fun: find_slots_fun)
  end

  test "resolve_slot_id/3 は parent_name 指定で1件に絞れれば解決できる" do
    slots = [
      %{slot_id: "slot_a", name: "CubeA", parent_name: "ParentA"},
      %{slot_id: "slot_b", name: "CubeA", parent_name: "ParentB"}
    ]

    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    get_slot_fun = fn _client, "slot_b" ->
      {:ok, %{type: "getSlot", payload: %{slot_id: "slot_b"}}}
    end

    assert {:ok, "slot_b"} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               parent_name: "ParentB",
               find_slots_fun: find_slots_fun,
               get_slot_fun: get_slot_fun
             )
  end

  test "resolve_slot_id/3 は getSlot 検証失敗時にエラーを返す" do
    find_slots_fun = fn _client, _name, _opts -> {:ok, [%{slot_id: "slot_a", name: "CubeA"}]} end
    get_slot_fun = fn _client, _slot_id -> {:error, :not_found} end

    assert {:error, :not_found} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               find_slots_fun: find_slots_fun,
               get_slot_fun: get_slot_fun
             )
  end

  test "resolve_slot_id/3 は不正入力で invalid_request を返す" do
    assert {:error, :invalid_request} = NameResolver.resolve_slot_id(:client, "", [])
    assert {:error, :invalid_request} = NameResolver.resolve_slot_id(:client, :name, [])
    assert {:error, :invalid_request} = NameResolver.resolve_slot_id(:client, "CubeA", :bad_opts)

    assert {:error, :invalid_request} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               get_slot_fun: fn _, _ -> {:ok, %{}} end
             )
  end

  test "resolve_slot_id/3 は不正な slot 要素を除外し not_found を返す" do
    find_slots_fun = fn _client, _name, _opts ->
      {:ok, [%{slot_id: "slot_a"}, %{name: "CubeA"}, %{slot_id: 1, name: "CubeA"}]}
    end

    assert {:error, :not_found} =
             NameResolver.resolve_slot_id(:client, "CubeA", find_slots_fun: find_slots_fun)
  end

  test "resolve_slot_id/3 は parent_name で絞り込み不可なら not_found を返す" do
    slots = [
      %{slot_id: "slot_a", name: "CubeA", parent_name: "ParentA"},
      %{slot_id: "slot_b", name: "CubeA", parent_name: "ParentB"}
    ]

    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    assert {:error, :not_found} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               parent_name: "ParentC",
               find_slots_fun: find_slots_fun
             )
  end

  test "resolve_slot_id/3 は parent_name 絞り込み後も複数なら ambiguous_name を返す" do
    slots = [
      %{slot_id: "slot_a", name: "CubeA", parent_name: "ParentA"},
      %{slot_id: "slot_b", name: "CubeA", parent_name: "ParentA"}
    ]

    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    assert {:error, :ambiguous_name} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               parent_name: "ParentA",
               find_slots_fun: find_slots_fun
             )
  end

  test "resolve_slot_id/3 は parent_name 型不正で invalid_request を返す" do
    slots = [
      %{slot_id: "slot_a", name: "CubeA", parent_name: "ParentA"},
      %{slot_id: "slot_b", name: "CubeA", parent_name: "ParentB"}
    ]

    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    assert {:error, :invalid_request} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               parent_name: 1,
               find_slots_fun: find_slots_fun
             )
  end

  test "resolve_slot_id/3 は slots が list でない場合 invalid_request を返す" do
    find_slots_fun = fn _client, _name, _opts -> {:ok, :not_list} end

    assert {:error, :invalid_request} =
             NameResolver.resolve_slot_id(:client, "CubeA", find_slots_fun: find_slots_fun)
  end

  test "resolve_slot_id/3 は default_get_slot で transport 経路を利用できる" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])

    assert {:ok, transport} =
             Client.start_link(client, host: "localhost", port: port)

    find_slots_fun = fn _client, _name, _opts -> {:ok, [%{slot_id: "slot_a", name: "CubeA"}]} end

    assert {:ok, "slot_a"} =
             NameResolver.resolve_slot_id(transport, "CubeA", find_slots_fun: find_slots_fun)

    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "resolve_slot_id/3 は default_get_slot の fallback で Client.call を使う" do
    assert {:ok, client} = Client.start_link([])
    find_slots_fun = fn _client, _name, _opts -> {:ok, [%{slot_id: "slot_a", name: "CubeA"}]} end

    assert {:ok, "slot_a"} =
             NameResolver.resolve_slot_id(client, "CubeA", find_slots_fun: find_slots_fun)
  end

  test "resolve_slot_id/3 は default_get_slot の fallback 経路でも解決できる" do
    assert {:ok, client} = Client.start_link([])
    {:ok, fake_transport} = Agent.start_link(fn -> %{client_pid: client} end)
    find_slots_fun = fn _client, _name, _opts -> {:ok, [%{slot_id: "slot_a", name: "CubeA"}]} end

    assert {:ok, "slot_a"} =
             NameResolver.resolve_slot_id(fake_transport, "CubeA", find_slots_fun: find_slots_fun)

    Agent.stop(fake_transport)
  end

  test "resolve_slot_id/3 は get_slot_fun が2引数関数でない場合 invalid_request を返す" do
    find_slots_fun = fn _client, _name, _opts -> {:ok, [%{slot_id: "slot_a", name: "CubeA"}]} end

    assert {:error, :invalid_request} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               find_slots_fun: find_slots_fun,
               get_slot_fun: fn _slot_id -> {:ok, %{}} end
             )
  end

  test "ensure_slot_id/3 は既存があればそれを返す" do
    find_slots_fun = fn _client, _name, _opts ->
      {:ok, [%{slot_id: "slot_existing", name: "ResoniteLinkEx"}]}
    end

    get_slot_fun = fn _client, _slot_id -> {:ok, %{}} end
    spawn_fun = fn _client, _name -> {:ok, %{slot_id: "slot_new"}} end

    assert {:ok, "slot_existing"} =
             NameResolver.ensure_slot_id(:client, "ResoniteLinkEx",
               find_slots_fun: find_slots_fun,
               get_slot_fun: get_slot_fun,
               spawn_fun: spawn_fun
             )
  end

  test "ensure_slot_id/3 は見つからない場合に生成して返す" do
    find_slots_fun = fn _client, _name, _opts -> {:ok, []} end
    get_slot_fun = fn _client, _slot_id -> {:ok, %{}} end
    spawn_fun = fn _client, "ResoniteLinkEx" -> {:ok, %{slot_id: "slot_new"}} end

    assert {:ok, "slot_new"} =
             NameResolver.ensure_slot_id(:client, "ResoniteLinkEx",
               find_slots_fun: find_slots_fun,
               get_slot_fun: get_slot_fun,
               spawn_fun: spawn_fun
             )
  end

  test "ensure_slot_id/3 は探索タイムアウトでも生成して返す" do
    find_slots_fun = fn _client, _name, _opts -> {:error, :request_timeout} end
    spawn_fun = fn _client, _name -> {:ok, %{slot_id: "slot_new"}} end

    assert {:ok, "slot_new"} =
             NameResolver.ensure_slot_id(:client, "ResoniteLinkEx",
               find_slots_fun: find_slots_fun,
               spawn_fun: spawn_fun
             )
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

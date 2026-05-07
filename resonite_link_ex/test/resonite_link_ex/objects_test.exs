defmodule ResoniteLinkEx.ObjectsTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Objects

  test "move_slot_by_name/4 は name 解決後に updateSlot を返す" do
    assert {:ok, client} = ResoniteLinkEx.start_client()
    resolver = fn _client, "CubeA", _opts -> {:ok, "slot_a"} end
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:ok, %{"$type" => "updateSlot", "data" => %{slot_id: "slot_a", position: ^position}}} =
             Objects.move_slot_by_name(client, "CubeA", position, resolve_slot_id_fun: resolver)
  end

  test "delete_slot_by_name/3 は name 解決後に removeSlot を返す" do
    assert {:ok, client} = ResoniteLinkEx.start_client()
    resolver = fn _client, "CubeA", _opts -> {:ok, "slot_a"} end

    assert {:ok, %{"$type" => "removeSlot", "data" => %{slot_id: "slot_a"}}} =
             Objects.delete_slot_by_name(client, "CubeA", resolve_slot_id_fun: resolver)
  end

  test "move_slot_by_name/4 は resolver のエラーを返す" do
    resolver = fn _client, _name, _opts -> {:error, :ambiguous_name} end
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:error, :ambiguous_name} =
             Objects.move_slot_by_name(:client, "CubeA", position, resolve_slot_id_fun: resolver)
  end

  test "delete_slot_by_name/3 は resolver のエラーを返す" do
    resolver = fn _client, _name, _opts -> {:error, :not_found} end

    assert {:error, :not_found} =
             Objects.delete_slot_by_name(:client, "CubeA", resolve_slot_id_fun: resolver)
  end

  test "move_slot/3 は slot_id 指定で updateSlot を返す" do
    assert {:ok, client} = ResoniteLinkEx.start_client()
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:ok, %{"$type" => "updateSlot", "data" => %{slot_id: "slot_a", position: ^position}}} =
             Objects.move_slot(client, "slot_a", position)
  end

  test "delete_slot/2 は slot_id 指定で removeSlot を返す" do
    assert {:ok, client} = ResoniteLinkEx.start_client()

    assert {:ok, %{"$type" => "removeSlot", "data" => %{slot_id: "slot_a"}}} =
             Objects.delete_slot(client, "slot_a")
  end

  test "Objects API は不正入力で invalid_request を返す" do
    resolver = fn _client, _name, _opts -> {:ok, "slot_a"} end

    assert {:error, :invalid_request} = Objects.move_slot_by_name(:client, "", %{}, [])

    assert {:error, :invalid_request} =
             Objects.move_slot_by_name(:client, "CubeA", %{"x" => 1, "y" => 2},
               resolve_slot_id_fun: resolver
             )

    assert {:error, :invalid_request} = Objects.delete_slot_by_name(:client, :bad, [])

    assert {:error, :invalid_request} =
             Objects.move_slot(:client, "", %{"x" => 1, "y" => 2, "z" => 3})

    assert {:error, :invalid_request} = Objects.delete_slot(:client, "")
  end

  test "move_slot_by_name/4 と delete_slot_by_name/3 は opts 型不正を拒否する" do
    assert {:error, :invalid_request} = Objects.move_slot_by_name(:client, "CubeA", %{}, :bad)
    assert {:error, :invalid_request} = Objects.delete_slot_by_name(:client, "CubeA", :bad)
  end

  test "move_slot_by_name/4 は position が map でなければ invalid_request を返す" do
    assert {:error, :invalid_request} = Objects.move_slot_by_name(:client, "CubeA", :bad, [])
  end

  test "move_slot_by_name/4 と delete_slot_by_name/3 はデフォルト opts を受け取れる" do
    assert {:error, :invalid_request} =
             Objects.move_slot_by_name(:client, "CubeA", %{"x" => 0, "y" => 1, "z" => 2})

    assert {:error, :invalid_request} = Objects.delete_slot_by_name(:client, "CubeA")
  end

  test "Objects API は transport 経路で updateSlot/removeSlot を送信できる" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])

    assert {:ok, transport} =
             Client.start_link(client, host: "localhost", port: port, path: "")

    resolver = fn _client, _name, _opts -> {:ok, "slot_a"} end
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:ok, %{"$type" => "updateSlot"}} =
             Objects.move_slot_by_name(transport, "CubeA", position,
               resolve_slot_id_fun: resolver
             )

    assert {:ok, %{"$type" => "removeSlot"}} =
             Objects.delete_slot_by_name(transport, "CubeA", resolve_slot_id_fun: resolver)

    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "Objects API は transport 経路で build 失敗時に invalid_request を返す" do
    {server_pid, port} = start_ws_mock_server()
    assert {:ok, client} = Client.start_link([])

    assert {:ok, transport} =
             Client.start_link(client, host: "localhost", port: port, path: "")

    resolver = fn _client, _name, _opts -> {:ok, 1} end
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:error, :invalid_request} =
             Objects.move_slot_by_name(transport, "CubeA", position,
               resolve_slot_id_fun: resolver
             )

    Process.exit(transport, :normal)
    Process.exit(server_pid, :normal)
  end

  test "Objects API は pid 以外の target を invalid_request で拒否する" do
    resolver = fn _client, _name, _opts -> {:ok, "slot_a"} end
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:error, :invalid_request} =
             Objects.move_slot_by_name(:not_pid, "CubeA", position, resolve_slot_id_fun: resolver)
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

defmodule ListComponentTypes do
  @moduledoc """
  ResoniteLink へ接続し、getComponentTypeList で利用可能コンポーネントを取得する。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Transport

  @host "localhost"

  def run do
    port = parse_port(System.argv())
    {:ok, client} = ResoniteLinkEx.start_client()
    {:ok, transport} = Transport.start_link(client, host: @host, port: port, path: "")
    wait_session_ready(client, 20)

    message_id = UUID.uuid4()
    request = %{
      "$type" => "getComponentTypeList",
      "messageId" => message_id,
      "categoryPath" => "*"
    }

    :ok = Client.register_pending(client, message_id, self())
    :ok = Transport.send_json(transport, request)

    response = wait_last_response(client, message_id, 40)
    raw = wait_raw_response(client, message_id, 40)
    IO.puts("=== raw last_response ===")
    IO.inspect(raw, pretty: true, limit: :infinity)
    print_summary(response)
    :ok
  end

  defp wait_session_ready(_client, 0) do
    raise "session_ready が true になりませんでした。ResoniteLink 接続状態を確認してください。"
  end

  defp wait_session_ready(client, retry_left) do
    if Client.session_ready?(client) do
      :ok
    else
      Process.sleep(100)
      wait_session_ready(client, retry_left - 1)
    end
  end

  defp wait_last_response(_client, _message_id, 0) do
    raise "getComponentTypeList の応答待機でタイムアウトしました。"
  end

  defp wait_raw_response(_client, _message_id, 0) do
    raise "生レスポンス取得でタイムアウトしました。"
  end

  defp wait_raw_response(client, message_id, retry_left) do
    case Client.last_response(client) do
      %{"sourceMessageId" => ^message_id} = response ->
        response

      _other ->
        Process.sleep(100)
        wait_raw_response(client, message_id, retry_left - 1)
    end
  end

  defp wait_last_response(client, message_id, retry_left) do
    case Client.last_response(client) do
      %{"sourceMessageId" => ^message_id} = response ->
        normalize_response(response)

      _other ->
        Process.sleep(100)
        wait_last_response(client, message_id, retry_left - 1)
    end
  end

  defp normalize_response(%{"componentTypeList" => _list} = response), do: response
  defp normalize_response(%{"data" => _data} = response), do: response

  defp normalize_response(response) do
    data =
      response
      |> Enum.reject(fn {k, _v} -> k in ["$type", "sourceMessageId", "messageId", "success", "errorInfo"] end)
      |> Map.new()

    Map.put(response, "data", data)
  end

  defp print_summary(%{"success" => true} = response) do
    data = Map.get(response, "data", %{})
    text = inspect(data, pretty: true, limit: :infinity)

    IO.puts("=== getComponentTypeList success ===")
    IO.puts(text)
  end

  defp print_summary(response) do
    IO.puts("=== getComponentTypeList failed ===")
    IO.inspect(response, pretty: true, limit: :infinity)
  end

  defp parse_port(args) do
    cleaned = Enum.reject(args, &(&1 == "--"))

    case cleaned do
      ["--port", port_text | _rest] -> parse_port_value(port_text)
      [port_text | _rest] -> parse_port_value(port_text)
      [] -> raise("ポート指定は必須です。例: mix run examples/list_component_types.exs -- --port 11943")
    end
  end

  defp parse_port_value(port_text) do
    case Integer.parse(port_text) do
      {port, ""} when port > 0 and port <= 65_535 -> port
      _ -> raise "ポート指定が不正です。1-65535 の整数を指定してください。例: --port 11943"
    end
  end
end

ListComponentTypes.run()

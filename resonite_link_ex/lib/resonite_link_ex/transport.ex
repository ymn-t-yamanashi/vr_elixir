defmodule ResoniteLinkEx.Transport do
  @moduledoc """
  Resonite との WebSocket 入出力を担当するトランスポート層です。

  主な責務:
  - WebSocket 接続の開始・維持
  - map <-> JSON の変換
  - テキスト受信時のデコードと `Client` への受け渡し
  - 切断イベントの正規化

  `Client` が状態管理、`Transport` が通信処理という分担で動作します。
  ネットワーク境界に最も近いモジュールです。
  """

  use WebSockex

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Protocol

  @default_host "localhost"
  @default_port 12_512
  @default_path ""

  @doc """
  トランスポートプロセスを起動する。

  ## Parameters
  - `client_pid`: 紐づく Client PID。
  - `opts`: 接続オプション。

  ## Returns
  - `{:ok, pid()}`: 起動成功。
  - `{:error, term()}`: 起動失敗。

  ## Examples
      ResoniteLinkEx.Transport.start_link(:bad, [])
      {:error, :invalid_request}
  """
  @spec start_link(pid(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(client_pid, opts) when is_pid(client_pid) and is_list(opts) do
    state = %{client_pid: client_pid, opts: opts}
    WebSockex.start_link(build_url(opts), __MODULE__, state, extra_headers: build_headers(opts))
  end

  def start_link(_client_pid, _opts), do: {:error, :invalid_request}

  @doc """
  トランスポートに紐づく client_pid を返す。

  ## Parameters
  - `transport_pid`: トランスポートPID。

  ## Returns
  - `{:ok, pid()} | {:error, :invalid_request}`: 解決結果。

  ## Examples
      ResoniteLinkEx.Transport.client_pid(:bad)
      {:error, :invalid_request}
  """
  @spec client_pid(pid()) :: {:ok, pid()} | {:error, :invalid_request}
  def client_pid(transport_pid) when transport_pid == self(), do: {:error, :invalid_request}

  def client_pid(transport_pid) when is_pid(transport_pid) do
    if Process.alive?(transport_pid) do
      case :sys.get_state(transport_pid) do
        %{client_pid: client_pid} when is_pid(client_pid) -> {:ok, client_pid}
        _other -> {:error, :invalid_request}
      end
    else
      {:error, :invalid_request}
    end
  end

  def client_pid(_transport_pid), do: {:error, :invalid_request}

  @doc """
  map ペイロードを JSON として送信する。

  ## Parameters
  - `transport_pid`: トランスポートPID。
  - `payload`: 送信 payload。

  ## Returns
  - `:ok | {:error, :invalid_request}`: 送信結果。

  ## Examples
      ResoniteLinkEx.Transport.send_json(:bad, %{})
      {:error, :invalid_request}
  """
  @spec send_json(pid(), map()) :: :ok | {:error, :invalid_request}
  def send_json(transport_pid, payload) when is_pid(transport_pid) and is_map(payload) do
    case Jason.encode(payload) do
      {:ok, json} ->
        WebSockex.cast(transport_pid, {:send_text, json})

      {:error, _reason} ->
        {:error, :invalid_request}
    end
  end

  def send_json(_transport_pid, _payload), do: {:error, :invalid_request}

  @doc """
  送信 map を JSON 文字列にエンコードする。

  ## Parameters
  - `payload`: 送信 payload。

  ## Returns
  - `{:ok, String.t()} | {:error, :invalid_request}`: 変換結果。

  ## Examples
      match?({:ok, _json}, ResoniteLinkEx.Transport.encode_outbound(%{"k" => "v"}))
      true
  """
  @spec encode_outbound(map()) :: {:ok, String.t()} | {:error, :invalid_request}
  def encode_outbound(payload) when is_map(payload), do: Jason.encode(payload)
  def encode_outbound(_payload), do: {:error, :invalid_request}

  @doc """
  受信 JSON 文字列を map にデコードする。

  ## Parameters
  - `json`: 受信 JSON。

  ## Returns
  - `{:ok, map()} | {:error, :decode_error}`: デコード結果。

  ## Examples
      ResoniteLinkEx.Transport.decode_inbound(~s({"k":"v"}))
      {:ok, %{"k" => "v"}}
  """
  @spec decode_inbound(String.t()) :: {:ok, map()} | {:error, :decode_error}
  def decode_inbound(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, payload} when is_map(payload) -> {:ok, payload}
      _ -> {:error, :decode_error}
    end
  end

  def decode_inbound(_json), do: {:error, :decode_error}

  @doc """
  切断理由を Client 側のトリガーへ変換する。

  ## Parameters
  - `reason`: 切断理由。

  ## Returns
  - `:close_frame | :tcp_error`: 正規化された理由。

  ## Examples
      ResoniteLinkEx.Transport.map_disconnect_reason({:remote, 1000, "ok"})
      :close_frame
  """
  @spec map_disconnect_reason(term()) :: :close_frame | :tcp_error
  def map_disconnect_reason({:remote, _code, _reason}), do: :close_frame
  def map_disconnect_reason({:local, _reason}), do: :close_frame
  def map_disconnect_reason({:error, _reason}), do: :tcp_error
  def map_disconnect_reason(_reason), do: :tcp_error

  @doc """
  接続 URL を生成する。

  ## Parameters
  - `opts`: `host` / `port` / `path` 設定。

  ## Returns
  - `String.t()`: WebSocket URL。

  ## Examples
      ResoniteLinkEx.Transport.build_url(host: "localhost", port: 12512, path: "")
      "ws://localhost:12512"
  """
  @spec build_url(keyword()) :: String.t()
  def build_url(opts) do
    host = Keyword.get(opts, :host, @default_host)
    port = Keyword.get(opts, :port, @default_port)
    path = Keyword.get(opts, :path, @default_path)
    "ws://#{host}:#{port}#{normalize_path(path)}"
  end

  @spec build_headers(keyword()) :: [{String.t(), String.t()}]
  defp build_headers(opts) do
    host = Keyword.get(opts, :host, @default_host)
    port = Keyword.get(opts, :port, @default_port)
    [{"Host", "#{host}:#{port}"}]
  end

  @impl true
  @doc """
  WebSocket 接続確立時に初期ハンドシェイクを送信する。

  ## Parameters
  - `_conn`: 接続情報。
  - `state`: 現在状態。

  ## Returns
  - `{:ok, map()}`: 更新後状態。

  ## Examples
      state = %{client_pid: self(), opts: []}
      match?({:ok, _}, ResoniteLinkEx.Transport.handle_connect(:connected, state))
      true
  """
  def handle_connect(_conn, state) do
    _ = Client.set_reconnecting(state.client_pid, false)
    _ = WebSockex.cast(self(), :send_initial_session_request)
    {:ok, state}
  end

  @impl true
  @doc """
  内部キャストを受け取り、初期要求または任意テキスト送信を処理する。

  ## Parameters
  - `message`: キャストメッセージ。
  - `state`: 現在状態。

  ## Returns
  - `{:reply, {:text, String.t()}, map()}`: 送信フレームと状態。

  ## Examples
      state = %{client_pid: self(), opts: []}
      match?({:reply, {:text, _}, _}, ResoniteLinkEx.Transport.handle_cast({:send_text, "hello"}, state))
      true
  """
  def handle_cast(:send_initial_session_request, state) do
    {:ok, request} = Protocol.encode_request("requestSessionData", %{})
    _ = Client.register_pending(state.client_pid, request["messageId"], self())
    {:ok, json} = encode_outbound(request)
    {:reply, {:text, json}, state}
  end

  @impl true
  def handle_cast({:send_text, json}, state) when is_binary(json) do
    {:reply, {:text, json}, state}
  end

  @impl true
  @doc """
  受信フレームをデコードして Client へ連携する。

  ## Parameters
  - `frame`: 受信フレーム。
  - `state`: 現在状態。

  ## Returns
  - `{:ok, map()}`: 更新後状態。

  ## Examples
      state = %{client_pid: self(), opts: []}
      ResoniteLinkEx.Transport.handle_frame({:binary, <<1, 2>>}, state)
      {:ok, state}
  """
  def handle_frame({:text, message}, state) do
    case decode_inbound(message) do
      {:ok, payload} -> _ = Client.receive_response(state.client_pid, payload)
      {:error, _reason} -> _ = Client.receive_response(state.client_pid, %{})
    end

    {:ok, state}
  end

  def handle_frame(_frame, state), do: {:ok, state}

  @impl true
  @doc """
  切断理由を判定して Client へ通知する。

  ## Parameters
  - `reason`: 切断理由。
  - `state`: 現在状態。

  ## Returns
  - `{:ok, map()}`: 更新後状態。

  ## Examples
      state = %{client_pid: self(), opts: []}
      ResoniteLinkEx.Transport.handle_disconnect(:unknown, state)
      {:ok, state}
  """
  def handle_disconnect(reason, state) do
    _ = Client.handle_disconnect(state.client_pid, map_disconnect_reason(reason))
    {:ok, state}
  end

  defp normalize_path(path) when is_binary(path) do
    cond do
      path == "" -> ""
      String.starts_with?(path, "/") -> path
      true -> "/#{path}"
    end
  end
end

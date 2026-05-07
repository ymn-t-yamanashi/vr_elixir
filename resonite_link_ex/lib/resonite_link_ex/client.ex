defmodule ResoniteLinkEx.Client do
  @moduledoc """
  Resonite 通信の状態管理を担当する `GenServer` モジュールです。

  このモジュールの主な責務は次のとおりです。
  - 接続中かどうかの判定
  - 送信リクエストの生成と pending 管理（`messageId` と待機プロセスの対応付け）
  - 受信レスポンスの解決と最終レスポンス保持
  - タイムアウトや切断時のエラー通知

  `Transport` がネットワーク入出力を行い、`Client` がアプリの状態を管理する、という分担です。
  リクエストとレスポンスを安全に対応付ける中核レイヤです。
  """

  alias ResoniteLinkEx.Protocol

  use GenServer
  require Logger

  @not_connected {:error, :not_connected}
  @invalid_request {:error, :invalid_request}
  @request_timeout {:error, :request_timeout}
  @default_request_timeout_ms 10_000

  @doc """
  クライアントプロセスを起動する。

  ## Parameters
  - `opts`: 起動オプション。

  ## Returns
  - `{:ok, pid()}`: 起動成功。
  - `{:error, term()}`: 起動失敗。

  ## Examples
      match?({:ok, pid} when is_pid(pid), ResoniteLinkEx.Client.start_link([]))
      true
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @doc """
  クライアントプロセスが生存していれば `true` を返す。

  ## Parameters
  - `pid`: 判定対象。

  ## Returns
  - `boolean()`: 生存中なら `true`。

  ## Examples
      ResoniteLinkEx.Client.connected?(:not_pid)
      false
  """
  @spec connected?(pid()) :: boolean()
  def connected?(pid) when is_pid(pid), do: Process.alive?(pid)
  def connected?(_pid), do: false

  @doc """
  統一IF。接続中ならリクエストを生成し、未接続ならエラーを返す。

  ## Parameters
  - `client`: `pid()`。
  - `type`: コマンド文字列。
  - `payload`: コマンド payload。

  ## Returns
  - `{:ok, map()}`: 生成成功。
  - `{:error, term()}`: 未接続または検証失敗。

  ## Examples
      ResoniteLinkEx.Client.call(:not_pid, "requestSessionData", %{})
      {:error, :not_connected}
  """
  @spec call(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(client, type, payload) do
    if connected?(client) and not reconnecting?(client),
      do: request(client, type, payload),
      else: @not_connected
  end

  @doc """
  接続中なら送信用リクエストを生成し、未接続ならエラーを返す。

  ## Parameters
  - `client`: `pid()`。
  - `type`: コマンド文字列。
  - `payload`: コマンド payload。

  ## Returns
  - `{:ok, map()}`: 生成成功。
  - `{:error, term()}`: 未接続または検証失敗。

  ## Examples
      ResoniteLinkEx.Client.request(:not_pid, "requestSessionData", %{})
      {:error, :not_connected}
  """
  @spec request(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def request(client, type, payload) do
    request(client, type, payload, @default_request_timeout_ms, &Protocol.encode_request/2)
  end

  @doc """
  接続中なら送信用リクエストを生成し、指定タイムアウト内に結果を返す。

  ## Parameters
  - `client`: `pid()`。
  - `type`: コマンド文字列。
  - `payload`: コマンド payload。
  - `timeout_ms`: タイムアウト（ミリ秒）。

  ## Returns
  - `{:ok, map()}`: 生成成功。
  - `{:error, term()}`: 未接続・入力不正・タイムアウト。

  ## Examples
      ResoniteLinkEx.Client.request(:not_pid, "requestSessionData", %{}, 1000)
      {:error, :not_connected}
  """
  @spec request(pid(), String.t(), map(), pos_integer()) :: {:ok, map()} | {:error, term()}
  def request(_client, _type, _payload, timeout_ms)
      when not is_integer(timeout_ms) or timeout_ms <= 0,
      do: @invalid_request

  def request(client, type, payload, timeout_ms) do
    request(client, type, payload, timeout_ms, &Protocol.encode_request/2)
  end

  @doc """
  request の内部拡張版。エンコード関数を差し替えて実行する。

  ## Parameters
  - `client`: `pid()`。
  - `type`: コマンド文字列。
  - `payload`: コマンド payload。
  - `timeout_ms`: タイムアウト（ミリ秒）。
  - `encode_fun`: エンコード関数。

  ## Returns
  - `{:ok, map()}`: 生成成功。
  - `{:error, term()}`: 未接続・入力不正・タイムアウト。

  ## Examples
      encode_fun = fn _type, _payload -> {:ok, %{"messageId" => "m1"}} end
      ResoniteLinkEx.Client.request(:not_pid, "requestSessionData", %{}, 1000, encode_fun)
      {:error, :not_connected}
  """
  @spec request(pid(), String.t(), map(), pos_integer(), (String.t(), map() ->
                                                            {:ok, map()} | {:error, term()})) ::
          {:ok, map()} | {:error, term()}
  def request(_client, _type, _payload, timeout_ms, _encode_fun)
      when not is_integer(timeout_ms) or timeout_ms <= 0,
      do: @invalid_request

  def request(client, type, payload, timeout_ms, encode_fun) do
    if connected?(client),
      do: await_request(client, type, payload, timeout_ms, encode_fun),
      else: @not_connected
  end

  defp await_request(client, type, payload, timeout_ms, encode_fun) do
    task = Task.async(fn -> encode_fun.(type, payload) end)

    try do
      case Task.await(task, timeout_ms) do
        {:ok, %{"messageId" => message_id} = request_map} when is_binary(message_id) ->
          :ok = register_pending(client, message_id, self())
          log_info("request_enqueued", message_id, type, "success")
          {:ok, request_map}

        result ->
          result
      end
    catch
      :exit, _reason ->
        _ = Task.shutdown(task, :brutal_kill)
        log_warn("request_timeout", nil, type, "request_timeout")
        @request_timeout
    end
  end

  @doc """
  `messageId` と待機元 pid を pending へ登録する。

  ## Parameters
  - `client`: `pid()`。
  - `message_id`: リクエストID。
  - `waiter_pid`: 待機元PID。

  ## Returns
  - `:ok`: 登録成功。
  - `{:error, :invalid_request}`: 入力不正。

  ## Examples
      ResoniteLinkEx.Client.register_pending(:bad, "m1", self())
      {:error, :invalid_request}
  """
  @spec register_pending(pid(), String.t(), pid()) :: :ok | {:error, :invalid_request}
  def register_pending(client, message_id, waiter_pid)
      when is_pid(client) and is_binary(message_id) and is_pid(waiter_pid) do
    GenServer.call(client, {:register_pending, message_id, waiter_pid})
  end

  def register_pending(_client, _message_id, _waiter_pid), do: @invalid_request

  @doc """
  `messageId` に対応する pending を解決して待機元 pid を返す。

  ## Parameters
  - `client`: `pid()`。
  - `message_id`: リクエストID。

  ## Returns
  - `{:ok, pid()}`: 解決成功。
  - `{:error, :unknown_message_id}`: 未登録。

  ## Examples
      ResoniteLinkEx.Client.resolve_pending(:bad, "m1")
      {:error, :unknown_message_id}
  """
  @spec resolve_pending(pid(), String.t()) :: {:ok, pid()} | {:error, :unknown_message_id}
  def resolve_pending(client, message_id) when is_pid(client) and is_binary(message_id) do
    GenServer.call(client, {:resolve_pending, message_id})
  end

  def resolve_pending(_client, _message_id), do: {:error, :unknown_message_id}

  @doc """
  現在の pending 件数を返す。

  ## Parameters
  - `client`: `pid()`。

  ## Returns
  - `non_neg_integer() | {:error, :invalid_request}`: 件数またはエラー。

  ## Examples
      ResoniteLinkEx.Client.pending_count(:bad)
      {:error, :invalid_request}
  """
  @spec pending_count(pid()) :: non_neg_integer() | {:error, :invalid_request}
  def pending_count(client) when is_pid(client), do: GenServer.call(client, :pending_count)
  def pending_count(_client), do: @invalid_request

  @doc """
  直近に受信して解決したレスポンスを返す。

  ## Parameters
  - `client`: `pid()`。

  ## Returns
  - `map() | nil | {:error, :invalid_request}`: 最終レスポンスまたはエラー。

  ## Examples
      ResoniteLinkEx.Client.last_response(:bad)
      {:error, :invalid_request}
  """
  @spec last_response(pid()) :: map() | nil | {:error, :invalid_request}
  def last_response(client) when is_pid(client), do: GenServer.call(client, :last_response)
  def last_response(_client), do: @invalid_request

  @doc """
  `requestSessionData` 成功応答を受信済みなら `true` を返す。

  ## Parameters
  - `client`: `pid()`。

  ## Returns
  - `boolean() | {:error, :invalid_request}`: セッション準備状態。

  ## Examples
      ResoniteLinkEx.Client.session_ready?(:bad)
      {:error, :invalid_request}
  """
  @spec session_ready?(pid()) :: boolean() | {:error, :invalid_request}
  def session_ready?(client) when is_pid(client), do: GenServer.call(client, :session_ready)
  def session_ready?(_client), do: @invalid_request

  @doc """
  再接続中なら `true` を返す。

  ## Parameters
  - `client`: `pid()`。

  ## Returns
  - `boolean() | {:error, :invalid_request}`: 再接続状態。

  ## Examples
      ResoniteLinkEx.Client.reconnecting?(:bad)
      {:error, :invalid_request}
  """
  @spec reconnecting?(pid()) :: boolean() | {:error, :invalid_request}
  def reconnecting?(client) when is_pid(client), do: GenServer.call(client, :reconnecting)
  def reconnecting?(_client), do: @invalid_request

  @doc """
  再接続状態を更新する。

  ## Parameters
  - `client`: `pid()`。
  - `reconnecting`: 設定値。

  ## Returns
  - `:ok | {:error, :invalid_request}`: 更新結果。

  ## Examples
      ResoniteLinkEx.Client.set_reconnecting(:bad, true)
      {:error, :invalid_request}
  """
  @spec set_reconnecting(pid(), boolean()) :: :ok | {:error, :invalid_request}
  def set_reconnecting(client, reconnecting)
      when is_pid(client) and is_boolean(reconnecting) do
    GenServer.call(client, {:set_reconnecting, reconnecting})
  end

  def set_reconnecting(_client, _reconnecting), do: @invalid_request

  @doc """
  切断検知トリガーを受け取り、接続状態を未確立へ戻す。

  ## Parameters
  - `client`: `pid()`。
  - `reason`: `:close_frame | :tcp_error`。

  ## Returns
  - `:ok | {:error, :invalid_request}`: 処理結果。

  ## Examples
      ResoniteLinkEx.Client.handle_disconnect(:bad, :tcp_error)
      {:error, :invalid_request}
  """
  @spec handle_disconnect(pid(), :close_frame | :tcp_error) :: :ok | {:error, :invalid_request}
  def handle_disconnect(client, reason)
      when is_pid(client) and reason in [:close_frame, :tcp_error] do
    GenServer.call(client, {:handle_disconnect, reason})
  end

  def handle_disconnect(_client, _reason), do: @invalid_request

  @doc """
  受信レスポンスを処理し、既知 `messageId` なら解決、未知なら warn ログのみ出力する。

  ## Parameters
  - `client`: `pid()`。
  - `response`: 受信 payload。

  ## Returns
  - `:ok | {:error, :decode_error} | {:error, :invalid_request}`: 処理結果。

  ## Examples
      ResoniteLinkEx.Client.receive_response(:bad, %{})
      {:error, :invalid_request}
  """
  @spec receive_response(pid(), map()) ::
          :ok | {:error, :decode_error} | {:error, :invalid_request}
  def receive_response(client, response) when is_pid(client) and is_map(response) do
    GenServer.call(client, {:receive_response, response})
  end

  def receive_response(_client, _response), do: @invalid_request

  @impl true
  @doc """
  クライアントの初期状態を構築する。

  ## Parameters
  - `opts`: 初期オプション。

  ## Returns
  - `{:ok, map()}`: 初期状態。

  ## Examples
      ResoniteLinkEx.Client.init([])
      {:ok, %{opts: [], pending: %{}, session_ready: false, reconnecting: false}}
  """
  def init(opts),
    do: {:ok, %{opts: opts, pending: %{}, session_ready: false, reconnecting: false}}

  @impl true
  @doc """
  pending 管理に関する同期リクエストを処理する。

  ## Parameters
  - `request`: 処理対象のリクエスト。
  - `from`: 呼び出し元情報。
  - `state`: 現在状態。

  ## Returns
  - `{:reply, term(), map()}`: 応答と更新後状態。

  ## Examples
      state = %{pending: %{}, opts: [], session_ready: false, reconnecting: false}
      match?({:reply, :ok, _}, ResoniteLinkEx.Client.handle_call({:register_pending, "m1", self()}, self(), state))
      true
  """
  def handle_call({:register_pending, message_id, waiter_pid}, _from, state) do
    pending = Map.put(state.pending, message_id, waiter_pid)
    {:reply, :ok, %{state | pending: pending}}
  end

  @impl true
  def handle_call({:resolve_pending, message_id}, _from, state) do
    case Map.pop(state.pending, message_id) do
      {nil, _pending} -> {:reply, {:error, :unknown_message_id}, state}
      {waiter_pid, pending} -> {:reply, {:ok, waiter_pid}, %{state | pending: pending}}
    end
  end

  @impl true
  def handle_call(:pending_count, _from, state), do: {:reply, map_size(state.pending), state}

  @impl true
  def handle_call(:last_response, _from, state),
    do: {:reply, Map.get(state, :last_response), state}

  @impl true
  def handle_call(:session_ready, _from, state), do: {:reply, state.session_ready, state}

  @impl true
  def handle_call(:reconnecting, _from, state), do: {:reply, state.reconnecting, state}

  @impl true
  def handle_call({:set_reconnecting, reconnecting}, _from, state) do
    {:reply, :ok, Map.put(state, :reconnecting, reconnecting)}
  end

  @impl true
  def handle_call({:handle_disconnect, reason}, _from, state) do
    log_warn("disconnect_detected", nil, nil, reason)

    {:reply, :ok,
     state
     |> Map.put(:session_ready, false)
     |> Map.put(:pending, %{})
     |> Map.put(:reconnecting, true)}
  end

  @impl true
  def handle_call({:receive_response, response}, _from, state) do
    case Protocol.decode_response(response) do
      {:ok, %{"messageId" => _message_id} = decoded} ->
        resolve_decoded_response(decoded, state)

      {:error, :decode_error} ->
        log_warn("decode_error", nil, nil, "decode_error")
        {:reply, {:error, :decode_error}, state}
    end
  end

  defp log_info(event, message_id, type, status) do
    Logger.info(log_line("info", event, message_id, type, status))
  end

  defp log_warn(event, message_id, type, error_reason) do
    Logger.warning(log_line("warn", event, message_id, type, error_reason))
  end

  defp log_line(level, event, message_id, type, status_or_error) do
    "timestamp=#{DateTime.utc_now() |> DateTime.to_iso8601()} level=#{level} event=#{event} message_id=#{message_id || "-"} $type=#{type || "-"} result=#{status_or_error}"
  end

  defp session_data_success?(%{"$type" => "sessionData", "success" => true}), do: true
  defp session_data_success?(_response), do: false

  defp resolve_decoded_response(%{"messageId" => message_id} = decoded, state) do
    case Map.pop(state.pending, message_id) do
      {nil, _pending} ->
        log_warn(
          "unknown_message_id",
          message_id,
          Map.get(decoded, "$type"),
          "unknown_message_id"
        )

        {:reply, :ok, state}

      {_waiter_pid, pending} ->
        session_data_success = session_data_success?(decoded)
        session_ready = state.session_ready or session_data_success
        reconnecting = if session_data_success, do: false, else: state.reconnecting

        {:reply, :ok,
         state
         |> Map.put(:pending, pending)
         |> Map.put(:last_response, decoded)
         |> Map.put(:session_ready, session_ready)
         |> Map.put(:reconnecting, reconnecting)}
    end
  end
end

defmodule ResoniteLinkEx.Client do
  @moduledoc """
  ResoniteLink 接続管理のクライアントモジュール。
  """

  alias ResoniteLinkEx.Protocol
  alias ResoniteLinkEx.Scene

  use GenServer
  require Logger

  @not_connected {:error, :not_connected}
  @invalid_request {:error, :invalid_request}
  @request_timeout {:error, :request_timeout}
  @default_request_timeout_ms 10_000

  @doc """
  クライアントプロセスを起動する。
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @doc """
  クライアントプロセスが生存していれば `true` を返す。
  """
  @spec connected?(pid()) :: boolean()
  def connected?(pid) when is_pid(pid), do: Process.alive?(pid)
  def connected?(_pid), do: false

  @doc """
  接続中なら Scene へ命令を委譲し、未接続ならエラーを返す。
  """
  @spec send_command(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def send_command(client, type, payload) do
    if connected?(client), do: Scene.call(client, type, payload), else: @not_connected
  end

  @doc """
  統一IF。接続中ならリクエストを生成し、未接続ならエラーを返す。
  """
  @spec call(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(client, type, payload) do
    if connected?(client) and not reconnecting?(client),
      do: request(client, type, payload),
      else: @not_connected
  end

  @doc """
  接続中なら送信用リクエストを生成し、未接続ならエラーを返す。
  """
  @spec request(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def request(client, type, payload) do
    request(client, type, payload, @default_request_timeout_ms, &Protocol.encode_request/2)
  end

  @doc """
  接続中なら送信用リクエストを生成し、指定タイムアウト内に結果を返す。
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
  """
  @spec register_pending(pid(), String.t(), pid()) :: :ok | {:error, :invalid_request}
  def register_pending(client, message_id, waiter_pid)
      when is_pid(client) and is_binary(message_id) and is_pid(waiter_pid) do
    GenServer.call(client, {:register_pending, message_id, waiter_pid})
  end

  def register_pending(_client, _message_id, _waiter_pid), do: @invalid_request

  @doc """
  `messageId` に対応する pending を解決して待機元 pid を返す。
  """
  @spec resolve_pending(pid(), String.t()) :: {:ok, pid()} | {:error, :unknown_message_id}
  def resolve_pending(client, message_id) when is_pid(client) and is_binary(message_id) do
    GenServer.call(client, {:resolve_pending, message_id})
  end

  def resolve_pending(_client, _message_id), do: {:error, :unknown_message_id}

  @doc """
  現在の pending 件数を返す。
  """
  @spec pending_count(pid()) :: non_neg_integer() | {:error, :invalid_request}
  def pending_count(client) when is_pid(client), do: GenServer.call(client, :pending_count)
  def pending_count(_client), do: @invalid_request

  @doc """
  直近に受信して解決したレスポンスを返す。
  """
  @spec last_response(pid()) :: map() | nil | {:error, :invalid_request}
  def last_response(client) when is_pid(client), do: GenServer.call(client, :last_response)
  def last_response(_client), do: @invalid_request

  @doc """
  `requestSessionData` 成功応答を受信済みなら `true` を返す。
  """
  @spec session_ready?(pid()) :: boolean() | {:error, :invalid_request}
  def session_ready?(client) when is_pid(client), do: GenServer.call(client, :session_ready)
  def session_ready?(_client), do: @invalid_request

  @doc """
  再接続中なら `true` を返す。
  """
  @spec reconnecting?(pid()) :: boolean() | {:error, :invalid_request}
  def reconnecting?(client) when is_pid(client), do: GenServer.call(client, :reconnecting)
  def reconnecting?(_client), do: @invalid_request

  @doc """
  再接続状態を更新する。
  """
  @spec set_reconnecting(pid(), boolean()) :: :ok | {:error, :invalid_request}
  def set_reconnecting(client, reconnecting)
      when is_pid(client) and is_boolean(reconnecting) do
    GenServer.call(client, {:set_reconnecting, reconnecting})
  end

  def set_reconnecting(_client, _reconnecting), do: @invalid_request

  @doc """
  切断検知トリガーを受け取り、接続状態を未確立へ戻す。
  """
  @spec handle_disconnect(pid(), :close_frame | :tcp_error) :: :ok | {:error, :invalid_request}
  def handle_disconnect(client, reason)
      when is_pid(client) and reason in [:close_frame, :tcp_error] do
    GenServer.call(client, {:handle_disconnect, reason})
  end

  def handle_disconnect(_client, _reason), do: @invalid_request

  @doc """
  受信レスポンスを処理し、既知 `messageId` なら解決、未知なら warn ログのみ出力する。
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
  """
  def init(opts),
    do: {:ok, %{opts: opts, pending: %{}, session_ready: false, reconnecting: false}}

  @impl true
  @doc """
  pending 管理に関する同期リクエストを処理する。
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

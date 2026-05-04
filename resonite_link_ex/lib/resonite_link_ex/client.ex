defmodule ResoniteLinkEx.Client do
  @moduledoc """
  ResoniteLink 接続管理のクライアントモジュール。
  """

  alias ResoniteLinkEx.Protocol
  alias ResoniteLinkEx.Scene

  use GenServer

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
          {:ok, request_map}

        result ->
          result
      end
    catch
      :exit, _reason ->
        _ = Task.shutdown(task, :brutal_kill)
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

  @impl true
  @doc """
  クライアントの初期状態を構築する。
  """
  def init(opts), do: {:ok, %{opts: opts, pending: %{}}}

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
end

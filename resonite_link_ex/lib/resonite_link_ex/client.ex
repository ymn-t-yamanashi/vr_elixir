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
      do: await_request(type, payload, timeout_ms, encode_fun),
      else: @not_connected
  end

  defp await_request(type, payload, timeout_ms, encode_fun) do
    task = Task.async(fn -> encode_fun.(type, payload) end)

    try do
      Task.await(task, timeout_ms)
    catch
      :exit, _reason -> @request_timeout
    end
  end

  @impl true
  @doc """
  クライアントの初期状態を構築する。
  """
  def init(opts), do: {:ok, %{opts: opts}}
end

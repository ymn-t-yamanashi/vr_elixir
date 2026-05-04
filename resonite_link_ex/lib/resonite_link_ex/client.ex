defmodule ResoniteLinkEx.Client do
  @moduledoc """
  ResoniteLink 接続管理のクライアントモジュール。
  """

  alias ResoniteLinkEx.Protocol
  alias ResoniteLinkEx.Scene

  use GenServer

  @not_connected {:error, :not_connected}

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
    if connected?(client), do: Protocol.encode_request(type, payload), else: @not_connected
  end

  @impl true
  @doc """
  クライアントの初期状態を構築する。
  """
  def init(opts), do: {:ok, %{opts: opts}}
end

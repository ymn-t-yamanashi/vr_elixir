defmodule ResoniteLinkEx.Client do
  @moduledoc """
  ResoniteLink 接続管理のクライアントモジュール。
  """

  use GenServer

  @doc """
  クライアントプロセスを起動する。
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl true
  @doc """
  クライアントの初期状態を構築する。
  """
  def init(opts), do: {:ok, %{opts: opts}}
end

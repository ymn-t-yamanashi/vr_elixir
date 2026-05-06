defmodule ResoniteLinkEx do
  @moduledoc """
  ResoniteLinkEx の公開エントリポイント。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.PortDiscovery
  alias ResoniteLinkEx.Shapes

  @doc """
  クライアントを起動する。
  """
  @spec start_client(keyword()) :: GenServer.on_start()
  def start_client(opts \\ []), do: Client.start_link(opts)

  @doc """
  統一IF。命令を呼び出す。
  """
  @spec call(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(client, type, payload), do: Client.call(client, type, payload)

  @doc """
  受信レスポンスを処理する。
  """
  @spec receive_response(pid(), map()) ::
          :ok | {:error, :decode_error} | {:error, :invalid_request}
  def receive_response(client, response), do: Client.receive_response(client, response)

  @doc """
  図形生成メッセージを送信する。
  """
  @spec spawn_shape(pid(), atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_shape(transport_pid, shape, opts), do: Shapes.spawn_shape(transport_pid, shape, opts)

  @doc """
  ResoniteLink の待受ポートを検出する。
  """
  @spec find_resonite_link_port() ::
          {:ok, pos_integer()}
          | {:error, :ss_not_found}
          | {:error, :command_failed}
          | {:error, :port_not_found}
  def find_resonite_link_port, do: PortDiscovery.find_resonite_link_port()

  @doc """
  テストや拡張用途向けに、コマンド実行関数を差し替えてポート検出する。
  """
  @spec find_resonite_link_port((String.t(), [String.t()] -> {String.t(), non_neg_integer()})) ::
          {:ok, pos_integer()}
          | {:error, :invalid_request}
          | {:error, :ss_not_found}
          | {:error, :command_failed}
          | {:error, :port_not_found}
  def find_resonite_link_port(cmd_fun), do: PortDiscovery.find_resonite_link_port(cmd_fun)
end

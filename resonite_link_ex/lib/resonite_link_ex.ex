defmodule ResoniteLinkEx do
  @moduledoc """
  ResoniteLinkEx の公開エントリポイント。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Objects
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
  Slot ID を指定して Slot 情報を取得する。
  """
  @spec get_slot(pid(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_slot(client, slot_id) when is_binary(slot_id),
    do: call(client, "getSlot", %{slot_id: slot_id})

  def get_slot(_client, _slot_id), do: {:error, :invalid_request}

  @doc """
  受信レスポンスを処理する。
  """
  @spec receive_response(pid(), map()) ::
          :ok | {:error, :decode_error} | {:error, :invalid_request}
  def receive_response(client, response), do: Client.receive_response(client, response)

  @doc """
  `name` で指定した対象を座標移動（位置更新）する。
  """
  @spec move_slot_by_name(term(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def move_slot_by_name(client_or_transport, name, position, opts \\ []),
    do: Objects.move_slot_by_name(client_or_transport, name, position, opts)

  @doc """
  `name` で指定した対象を削除する。
  """
  @spec delete_slot_by_name(term(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete_slot_by_name(client_or_transport, name, opts \\ []),
    do: Objects.delete_slot_by_name(client_or_transport, name, opts)

  @doc """
  互換API。`slot_id` 指定で座標移動（位置更新）する。
  """
  @spec move_slot(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def move_slot(client_or_transport, slot_id, position),
    do: Objects.move_slot(client_or_transport, slot_id, position)

  @doc """
  互換API。`slot_id` 指定で削除する。
  """
  @spec delete_slot(term(), String.t()) :: {:ok, map()} | {:error, term()}
  def delete_slot(client_or_transport, slot_id),
    do: Objects.delete_slot(client_or_transport, slot_id)

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

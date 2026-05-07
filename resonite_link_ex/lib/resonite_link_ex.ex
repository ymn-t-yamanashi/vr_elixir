defmodule ResoniteLinkEx do
  @moduledoc """
  ResoniteLinkEx の公開エントリポイント。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Objects
  alias ResoniteLinkEx.PortDiscovery
  alias ResoniteLinkEx.Shapes

  @doc """
  ResoniteLink クライアントを起動する。

  ## Parameters
  - `opts`: クライアント起動オプション。

  ## Returns
  - `{:ok, pid()}`: 起動成功。
  - `{:error, term()}`: 起動失敗。

  ## Examples
      iex> match?({:ok, pid} when is_pid(pid), ResoniteLinkEx.start_client([]))
      true
  """
  @spec start_client(keyword()) :: GenServer.on_start()
  def start_client(opts \\ []), do: Client.start_link(opts)

  @doc """
  `$type` と `payload` を指定して命令を呼び出す。

  ## Parameters
  - `client`: `pid()`。
  - `type`: `String.t()`。
  - `payload`: `map()`。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正や未接続など。

  ## Examples
      iex> payload = %{parent_id: "Root", name: "BoxA"}
      iex> {:ok, client} = ResoniteLinkEx.start_client([])
      iex> match?({:ok, %{"$type" => "addSlot"}}, ResoniteLinkEx.call(client, "addSlot", payload))
      true
  """
  @spec call(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(client, type, payload), do: Client.call(client, type, payload)

  @doc """
  Slot ID を指定して `getSlot` を呼び出す。

  ## Parameters
  - `client`: `pid()`。
  - `slot_id`: `String.t()`。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, :invalid_request | term()}`: 入力不正など。

  ## Examples
      iex> {:ok, client} = ResoniteLinkEx.start_client([])
      iex> match?({:ok, %{"$type" => "getSlot"}}, ResoniteLinkEx.get_slot(client, "SlotA"))
      true
  """
  @spec get_slot(pid(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_slot(client, slot_id) when is_binary(slot_id),
    do: call(client, "getSlot", %{slot_id: slot_id})

  def get_slot(_client, _slot_id), do: {:error, :invalid_request}

  @doc """
  受信レスポンスを処理する。

  ## Parameters
  - `client`: `pid()`。
  - `response`: `map()`。

  ## Returns
  - `:ok`: 処理成功。
  - `{:error, :decode_error | :invalid_request}`: 解析失敗または入力不正。

  ## Examples
      iex> ResoniteLinkEx.receive_response(:not_pid, %{})
      {:error, :invalid_request}
  """
  @spec receive_response(pid(), map()) ::
          :ok | {:error, :decode_error} | {:error, :invalid_request}
  def receive_response(client, response), do: Client.receive_response(client, response)

  @doc """
  `name` で指定した対象を座標移動（位置更新）する。

  ## Parameters
  - `client_or_transport`: `pid()`。
  - `name`: `String.t()`。
  - `position`: `%{"x" => number(), "y" => number(), "z" => number()}`。
  - `opts`: 解決関数差し替えなどのオプション。

  ## Returns
  - `{:ok, map()}`: `updateSlot` 送信成功。
  - `{:error, term()}`: 解決失敗または入力不正。

  ## Examples
      iex> position = %{"x" => 0, "y" => 1, "z" => 2}
      iex> {:ok, client} = ResoniteLinkEx.start_client([])
      iex> resolver = fn _client, _name, _opts -> {:ok, "SlotA"} end
      iex> match?({:ok, %{"$type" => "updateSlot"}}, ResoniteLinkEx.move_slot_by_name(client, "CubeA", position, resolve_slot_id_fun: resolver))
      true
  """
  @spec move_slot_by_name(term(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def move_slot_by_name(client_or_transport, name, position, opts \\ []),
    do: Objects.move_slot_by_name(client_or_transport, name, position, opts)

  @doc """
  `name` で指定した対象を削除する。

  ## Parameters
  - `client_or_transport`: `pid()`。
  - `name`: `String.t()`。
  - `opts`: 解決関数差し替えなどのオプション。

  ## Returns
  - `{:ok, map()}`: `removeSlot` 送信成功。
  - `{:error, term()}`: 解決失敗または入力不正。

  ## Examples
      iex> {:ok, client} = ResoniteLinkEx.start_client([])
      iex> resolver = fn _client, _name, _opts -> {:ok, "SlotA"} end
      iex> match?({:ok, %{"$type" => "removeSlot"}}, ResoniteLinkEx.delete_slot_by_name(client, "CubeA", resolve_slot_id_fun: resolver))
      true
  """
  @spec delete_slot_by_name(term(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete_slot_by_name(client_or_transport, name, opts \\ []),
    do: Objects.delete_slot_by_name(client_or_transport, name, opts)

  @doc """
  互換API。`slot_id` 指定で座標移動（位置更新）する。

  ## Parameters
  - `client_or_transport`: `pid()`。
  - `slot_id`: `String.t()`。
  - `position`: `%{"x" => number(), "y" => number(), "z" => number()}`。

  ## Returns
  - `{:ok, map()}`: `updateSlot` 送信成功。
  - `{:error, term()}`: 入力不正または送信失敗。

  ## Examples
      iex> position = %{"x" => 0, "y" => 1, "z" => 2}
      iex> {:ok, client} = ResoniteLinkEx.start_client([])
      iex> match?({:ok, %{"$type" => "updateSlot"}}, ResoniteLinkEx.move_slot(client, "SlotA", position))
      true
  """
  @spec move_slot(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def move_slot(client_or_transport, slot_id, position),
    do: Objects.move_slot(client_or_transport, slot_id, position)

  @doc """
  互換API。`slot_id` 指定で削除する。

  ## Parameters
  - `client_or_transport`: `pid()`。
  - `slot_id`: `String.t()`。

  ## Returns
  - `{:ok, map()}`: `removeSlot` 送信成功。
  - `{:error, term()}`: 入力不正または送信失敗。

  ## Examples
      iex> {:ok, client} = ResoniteLinkEx.start_client([])
      iex> match?({:ok, %{"$type" => "removeSlot"}}, ResoniteLinkEx.delete_slot(client, "SlotA"))
      true
  """
  @spec delete_slot(term(), String.t()) :: {:ok, map()} | {:error, term()}
  def delete_slot(client_or_transport, slot_id),
    do: Objects.delete_slot(client_or_transport, slot_id)

  @doc """
  図形生成メッセージを送信する。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `shape`: `atom()`。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()}`: 生成 ID 群。
  - `{:error, term()}`: 入力不正または送信失敗。

  ## Examples
      iex> send_fun = fn _transport_pid, _payload -> :ok end
      iex> match?({:ok, _ids}, ResoniteLinkEx.spawn_shape(self(), :quad, name: "QuadA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_shape(pid(), atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_shape(transport_pid, shape, opts), do: Shapes.spawn_shape(transport_pid, shape, opts)

  @doc """
  ResoniteLink の待受ポートを検出する。

  ## Returns
  - `{:ok, pos_integer()}`: ポート検出成功。
  - `{:error, :ss_not_found | :command_failed | :port_not_found}`: 検出失敗。

  ## Examples
      iex> result = ResoniteLinkEx.find_resonite_link_port()
      iex> is_tuple(result) and tuple_size(result) == 2
      true
  """
  @spec find_resonite_link_port() ::
          {:ok, pos_integer()}
          | {:error, :ss_not_found}
          | {:error, :command_failed}
          | {:error, :port_not_found}
  def find_resonite_link_port, do: PortDiscovery.find_resonite_link_port()

  @doc """
  テストや拡張用途向けに、コマンド実行関数を差し替えてポート検出する。

  ## Parameters
  - `cmd_fun`: `"ss -ltnp"` 相当の実行関数。

  ## Returns
  - `{:ok, pos_integer()}`: ポート検出成功。
  - `{:error, :invalid_request | :ss_not_found | :command_failed | :port_not_found}`: 検出失敗。

  ## Examples
      iex> cmd_fun = fn "ss", ["-ltnp"] -> {"LISTEN 0 500 127.0.0.1:55555 0.0.0.0:* users:((\\\"dotnet\\\",pid=1,fd=1))", 0} end
      iex> ResoniteLinkEx.find_resonite_link_port(cmd_fun)
      {:ok, 55555}
  """
  @spec find_resonite_link_port((String.t(), [String.t()] -> {String.t(), non_neg_integer()})) ::
          {:ok, pos_integer()}
          | {:error, :invalid_request}
          | {:error, :ss_not_found}
          | {:error, :command_failed}
          | {:error, :port_not_found}
  def find_resonite_link_port(cmd_fun), do: PortDiscovery.find_resonite_link_port(cmd_fun)
end

defmodule ResoniteLinkEx do
  @moduledoc """
  このライブラリの公開入口（Facade）です。

  Resonite 連携でよく使う機能を、分かりやすい関数名でまとめて提供します。
  具体的には次を扱います。
  - クライアント起動（`start_client/1`）
  - 受信レスポンス処理（`receive_response/2`）
  - オブジェクト移動・削除（`move_slot_by_name/4`, `delete_slot_by_name/3`）
  - 図形生成（`spawn_shape/3`）
  - ポート自動検出（`find_resonite_link_port/0`）

  内部には `Client` / `Objects` / `Shapes` / `PortDiscovery` などの専用モジュールがありますが、
  初学者はまず本モジュールだけを使って開始できます。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Objects
  alias ResoniteLinkEx.PortDiscovery
  alias ResoniteLinkEx.Shapes

  @doc """
  Resonite通信用の `Client` プロセスを起動し、以後のAPI呼び出しに使うPIDを返す。

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
  Transportなどで受け取ったレスポンスを `Client` に渡し、pending解決と状態更新を行う。

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
  名前で対象オブジェクトを特定し、そのオブジェクトの位置を更新する（推奨API）。

  ## Parameters
  - `client`: `pid()`。
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
  def move_slot_by_name(client, name, position, opts \\ []),
    do: Objects.move_slot_by_name(client, name, position, opts)

  @doc """
  名前で対象オブジェクトを特定し、そのオブジェクトを削除する（推奨API）。

  ## Parameters
  - `client`: `pid()`。
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
  def delete_slot_by_name(client, name, opts \\ []),
    do: Objects.delete_slot_by_name(client, name, opts)

  @doc """
  互換APIとして、`slot_id` を直接指定してオブジェクトの位置を更新する。

  ## Parameters
  - `client`: `pid()`。
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
  def move_slot(client, slot_id, position),
    do: Objects.move_slot(client, slot_id, position)

  @doc """
  互換APIとして、`slot_id` を直接指定してオブジェクトを削除する。

  ## Parameters
  - `client`: `pid()`。
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
  def delete_slot(client, slot_id),
    do: Objects.delete_slot(client, slot_id)

  @doc """
  指定した図形の生成に必要なメッセージ群を送信し、生成ID情報を返す。

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
  実行中のResoniteLinkが待ち受けているローカルポートを自動検出する。

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
  テストや拡張向けにコマンド実行関数を差し替えて、同じポート検出ロジックを実行する。

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

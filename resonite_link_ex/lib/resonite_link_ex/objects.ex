defmodule ResoniteLinkEx.Objects do
  @moduledoc """
  既存オブジェクトを操作するユースケース層モジュールです。

  主な機能:
  - 名前指定で移動（`move_slot_by_name/4`）
  - 名前指定で削除（`delete_slot_by_name/3`）
  - 互換APIとしてID指定の移動・削除（`move_slot/3`, `delete_slot/2`）

  名前指定のときは内部で `NameResolver` を使って `slot_id` を解決し、
  その後 `Core` でリクエストを作成して送信処理へ渡します。
  「アプリの操作意図」と「低レイヤ通信」をつなぐ役割のモジュールです。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Core
  alias ResoniteLinkEx.NameResolver
  alias ResoniteLinkEx.Transport

  require Logger

  @invalid_request {:error, :invalid_request}

  @doc """
  名前から対象を解決して位置更新し、オブジェクトを移動する。

  ## Parameters
  - `client_or_transport`: `pid()`。
  - `name`: 対象 Slot 名。
  - `position`: `%{"x" => number(), "y" => number(), "z" => number()}`。
  - `opts`: 解決関数差し替えなどのオプション。

  ## Returns
  - `{:ok, map()}`: 送信成功。
  - `{:error, :invalid_request | :not_found | :ambiguous_name | term()}`: 入力不正または解決失敗。

  ## Examples
      resolver = fn _client, _name, _opts -> {:ok, "slot_a"} end
      position = %{"x" => 1, "y" => 2, "z" => 3}
      match?({:ok, %{"$type" => "updateSlot"}}, ResoniteLinkEx.Objects.move_slot_by_name(client, "CubeA", position, resolve_slot_id_fun: resolver))
      true
  """
  @spec move_slot_by_name(term(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, :invalid_request | :not_found | :ambiguous_name | term()}
  def move_slot_by_name(client_or_transport, name, position, opts \\ [])

  def move_slot_by_name(_client_or_transport, name, _position, _opts)
      when not is_binary(name) or name == "",
      do: @invalid_request

  def move_slot_by_name(_client_or_transport, _name, position, _opts) when not is_map(position),
    do: @invalid_request

  def move_slot_by_name(_client_or_transport, _name, _position, opts) when not is_list(opts),
    do: @invalid_request

  def move_slot_by_name(client_or_transport, name, position, opts) do
    with :ok <- validate_position(position),
         {:ok, slot_id} <- resolve_slot_id(client_or_transport, name, opts) do
      request_via_core =
        Core.update_slot(client_or_transport, %{slot_id: slot_id, position: position})

      dispatch_core_request(client_or_transport, request_via_core)
    end
  end

  @doc """
  名前から対象を解決して削除し、オブジェクトを消去する。

  ## Parameters
  - `client_or_transport`: `pid()`。
  - `name`: 対象 Slot 名。
  - `opts`: 解決関数差し替えなどのオプション。

  ## Returns
  - `{:ok, map()}`: 送信成功。
  - `{:error, :invalid_request | :not_found | :ambiguous_name | term()}`: 入力不正または解決失敗。

  ## Examples
      resolver = fn _client, _name, _opts -> {:ok, "slot_a"} end
      match?({:ok, %{"$type" => "removeSlot"}}, ResoniteLinkEx.Objects.delete_slot_by_name(client, "CubeA", resolve_slot_id_fun: resolver))
      true
  """
  @spec delete_slot_by_name(term(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :invalid_request | :not_found | :ambiguous_name | term()}
  def delete_slot_by_name(client_or_transport, name, opts \\ [])

  def delete_slot_by_name(_client_or_transport, name, _opts)
      when not is_binary(name) or name == "",
      do: @invalid_request

  def delete_slot_by_name(_client_or_transport, _name, opts) when not is_list(opts),
    do: @invalid_request

  def delete_slot_by_name(client_or_transport, name, opts) do
    with {:ok, slot_id} <- resolve_slot_id(client_or_transport, name, opts) do
      request_via_core = Core.remove_slot(client_or_transport, %{slot_id: slot_id})
      dispatch_core_request(client_or_transport, request_via_core)
    end
  end

  @doc """
  互換APIとして `slot_id` 直接指定で位置更新する。

  ## Parameters
  - `client_or_transport`: `pid()`。
  - `slot_id`: 対象 Slot ID。
  - `position`: `%{"x" => number(), "y" => number(), "z" => number()}`。

  ## Returns
  - `{:ok, map()}`: 送信成功。
  - `{:error, term()}`: 入力不正または送信失敗。

  ## Examples
      position = %{"x" => 1, "y" => 2, "z" => 3}
      match?({:ok, %{"$type" => "updateSlot"}}, ResoniteLinkEx.Objects.move_slot(client, "slot_a", position))
      true
  """
  @spec move_slot(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def move_slot(client_or_transport, slot_id, position)
      when is_binary(slot_id) and slot_id != "" and is_map(position) do
    Logger.warning("[deprecated] move_slot/3 は将来削除予定です。move_slot_by_name/4 を利用してください")

    with :ok <- validate_position(position) do
      request_via_core =
        Core.update_slot(client_or_transport, %{slot_id: slot_id, position: position})

      dispatch_core_request(client_or_transport, request_via_core)
    end
  end

  def move_slot(_client_or_transport, _slot_id, _position), do: @invalid_request

  @doc """
  互換APIとして `slot_id` 直接指定で削除する。

  ## Parameters
  - `client_or_transport`: `pid()`。
  - `slot_id`: 対象 Slot ID。

  ## Returns
  - `{:ok, map()}`: 送信成功。
  - `{:error, term()}`: 入力不正または送信失敗。

  ## Examples
      match?({:ok, %{"$type" => "removeSlot"}}, ResoniteLinkEx.Objects.delete_slot(client, "slot_a"))
      true
  """
  @spec delete_slot(term(), String.t()) :: {:ok, map()} | {:error, term()}
  def delete_slot(client_or_transport, slot_id) when is_binary(slot_id) and slot_id != "" do
    Logger.warning("[deprecated] delete_slot/2 は将来削除予定です。delete_slot_by_name/3 を利用してください")
    request_via_core = Core.remove_slot(client_or_transport, %{slot_id: slot_id})
    dispatch_core_request(client_or_transport, request_via_core)
  end

  def delete_slot(_client_or_transport, _slot_id), do: @invalid_request

  defp resolve_slot_id(client_or_transport, name, opts) do
    resolver_fun = Keyword.get(opts, :resolve_slot_id_fun, &NameResolver.resolve_slot_id/3)

    if is_function(resolver_fun, 3) do
      resolver_fun.(client_or_transport, name, opts)
    else
      @invalid_request
    end
  end

  defp validate_position(%{"x" => x, "y" => y, "z" => z})
       when is_number(x) and is_number(y) and is_number(z),
       do: :ok

  defp validate_position(_position), do: @invalid_request

  defp dispatch_core_request(target_pid, {:ok, %{type: _type, payload: _payload} = core_request})
       when is_pid(target_pid) do
    case Transport.client_pid(target_pid) do
      {:ok, client_pid} -> send_over_transport(target_pid, client_pid, core_request)
      {:error, :invalid_request} -> normalize_core_result(core_request)
    end
  end

  defp dispatch_core_request(
         _target_pid,
         {:ok, %{type: _type, payload: _payload}}
       ),
       do: @invalid_request

  defp dispatch_core_request(_target_pid, {:error, reason}), do: {:error, reason}
  defp dispatch_core_request(_target_pid, _unknown), do: @invalid_request

  defp send_over_transport(target_pid, client_pid, %{type: type, payload: payload}) do
    with :ok <- validate_transport_payload(type, payload),
         {:ok, request} <- encode_objects_transport_request(type, payload),
         :ok <- Client.register_pending(client_pid, request["messageId"], self()),
         :ok <- Transport.send_json(target_pid, request) do
      {:ok, request}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_core_result(%{type: type, payload: payload})
       when is_binary(type) and is_map(payload),
       do: {:ok, %{"$type" => type, "data" => payload}}

  defp normalize_core_result(_core_request), do: @invalid_request

  defp validate_transport_payload("updateSlot", %{slot_id: slot_id, position: position})
       when is_binary(slot_id) and is_map(position),
       do: :ok

  defp validate_transport_payload("removeSlot", %{slot_id: slot_id}) when is_binary(slot_id),
    do: :ok

  defp validate_transport_payload("updateSlot", _payload), do: @invalid_request
  defp validate_transport_payload("removeSlot", _payload), do: @invalid_request
  defp validate_transport_payload(_type, _payload), do: :ok

  # Objects API の transport 経路は既存Wire形式を維持する。
  defp encode_objects_transport_request("updateSlot", %{slot_id: slot_id, position: position})
       when is_binary(slot_id) and is_map(position) do
    {:ok,
     %{
       "messageId" => UUID.uuid4(),
       "$type" => "updateSlot",
       "data" => %{
         "id" => slot_id,
         "position" => %{"$type" => "float3", "value" => position}
       }
     }}
  end

  defp encode_objects_transport_request("removeSlot", %{slot_id: slot_id})
       when is_binary(slot_id) do
    {:ok, %{"messageId" => UUID.uuid4(), "$type" => "removeSlot", "slotId" => slot_id}}
  end

  defp encode_objects_transport_request(_type, _payload), do: @invalid_request
end

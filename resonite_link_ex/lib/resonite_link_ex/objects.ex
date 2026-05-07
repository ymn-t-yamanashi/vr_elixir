defmodule ResoniteLinkEx.Objects do
  @moduledoc """
  生成済みオブジェクトの座標移動・削除API。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.NameResolver
  alias ResoniteLinkEx.Transport

  require Logger

  @invalid_request {:error, :invalid_request}

  @doc """
  `name` を解決して `updateSlot` を送信し、座標移動（位置更新）する。

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
      send_command(client_or_transport, "updateSlot", %{slot_id: slot_id, position: position})
    end
  end

  @doc """
  `name` を解決して `removeSlot` を送信し、対象Slotを削除する。

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
      send_command(client_or_transport, "removeSlot", %{slot_id: slot_id})
    end
  end

  @doc """
  互換API。`slot_id` 指定で `updateSlot` を送信する。

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
      send_command(client_or_transport, "updateSlot", %{slot_id: slot_id, position: position})
    end
  end

  def move_slot(_client_or_transport, _slot_id, _position), do: @invalid_request

  @doc """
  互換API。`slot_id` 指定で `removeSlot` を送信する。

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
    send_command(client_or_transport, "removeSlot", %{slot_id: slot_id})
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

  defp send_command(target_pid, type, payload) when is_pid(target_pid) do
    case Transport.client_pid(target_pid) do
      {:ok, client_pid} ->
        with {:ok, request} <- build_transport_request(type, payload),
             :ok <- Client.register_pending(client_pid, request["messageId"], self()),
             :ok <- Transport.send_json(target_pid, request) do
          {:ok, request}
        else
          {:error, reason} -> {:error, reason}
        end

      {:error, :invalid_request} ->
        Client.call(target_pid, type, payload)
    end
  end

  defp send_command(_target_pid, _type, _payload), do: @invalid_request

  defp build_transport_request("updateSlot", %{slot_id: slot_id, position: position})
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

  defp build_transport_request("removeSlot", %{slot_id: slot_id}) when is_binary(slot_id) do
    {:ok, %{"messageId" => UUID.uuid4(), "$type" => "removeSlot", "slotId" => slot_id}}
  end

  defp build_transport_request(_type, _payload), do: @invalid_request
end

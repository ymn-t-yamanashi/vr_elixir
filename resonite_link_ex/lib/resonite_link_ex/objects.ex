defmodule ResoniteLinkEx.Objects do
  @moduledoc """
  生成済みオブジェクトの座標移動・削除API。
  """

  alias ResoniteLinkEx.NameResolver
  alias ResoniteLinkEx.Scene

  require Logger

  @invalid_request {:error, :invalid_request}

  @doc """
  `name` を解決して `updateSlot` を送信し、座標移動（位置更新）する。
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
      Scene.call(client_or_transport, "updateSlot", %{slot_id: slot_id, position: position})
    end
  end

  @doc """
  `name` を解決して `removeSlot` を送信し、対象Slotを削除する。
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
      Scene.call(client_or_transport, "removeSlot", %{slot_id: slot_id})
    end
  end

  @doc """
  互換API。`slot_id` 指定で `updateSlot` を送信する。
  """
  @spec move_slot(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def move_slot(client_or_transport, slot_id, position)
      when is_binary(slot_id) and slot_id != "" and is_map(position) do
    Logger.warning("[deprecated] move_slot/3 は将来削除予定です。move_slot_by_name/4 を利用してください")

    with :ok <- validate_position(position) do
      Scene.call(client_or_transport, "updateSlot", %{slot_id: slot_id, position: position})
    end
  end

  def move_slot(_client_or_transport, _slot_id, _position), do: @invalid_request

  @doc """
  互換API。`slot_id` 指定で `removeSlot` を送信する。
  """
  @spec delete_slot(term(), String.t()) :: {:ok, map()} | {:error, term()}
  def delete_slot(client_or_transport, slot_id) when is_binary(slot_id) and slot_id != "" do
    Logger.warning("[deprecated] delete_slot/2 は将来削除予定です。delete_slot_by_name/3 を利用してください")
    Scene.call(client_or_transport, "removeSlot", %{slot_id: slot_id})
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
end

defmodule ResoniteLinkEx.Scene do
  @moduledoc """
  ResoniteLink 命令呼び出しの入口API。
  """

  alias ResoniteLinkEx.Protocol

  @invalid_request {:error, :invalid_request}
  @not_implemented {:error, :not_implemented}
  @type_request_session_data "requestSessionData"
  @type_add_slot "addSlot"
  @type_update_slot "updateSlot"
  @type_add_component "addComponent"
  @type_update_component "updateComponent"
  @type_remove_component "removeComponent"
  @type_remove_slot "removeSlot"

  @doc """
  指定した `$type` と `payload` で命令を呼び出す。
  """
  @spec call(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(_client, type, _payload) when not is_binary(type), do: @invalid_request
  def call(_client, _type, payload) when not is_map(payload), do: @invalid_request

  def call(_client, @type_request_session_data, payload) when map_size(payload) == 0,
    do: @not_implemented

  def call(_client, @type_request_session_data, _payload), do: @invalid_request

  def call(_client, @type_add_slot, %{parent_id: _parent_id, name: _name}),
    do: @not_implemented

  def call(_client, @type_add_slot, _payload), do: @invalid_request

  def call(_client, @type_update_slot, payload),
    do: map_result(Protocol.validate_payload(@type_update_slot, payload))

  def call(_client, @type_add_component, payload),
    do: map_result(Protocol.validate_payload(@type_add_component, payload))

  def call(_client, @type_update_component, payload),
    do: map_result(Protocol.validate_payload(@type_update_component, payload))

  def call(_client, @type_remove_component, payload),
    do: map_result(Protocol.validate_payload(@type_remove_component, payload))

  def call(_client, @type_remove_slot, payload),
    do: map_result(Protocol.validate_payload(@type_remove_slot, payload))

  def call(_client, _type, _payload), do: @invalid_request

  defp map_result({:ok, _payload}), do: @not_implemented
  defp map_result(_error), do: @invalid_request
end

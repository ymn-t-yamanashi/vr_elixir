defmodule ResoniteLinkEx.Scene do
  @moduledoc """
  ResoniteLink 命令呼び出しの入口API。
  """

  @invalid_request {:error, :invalid_request}
  @not_implemented {:error, :not_implemented}
  @type_request_session_data "requestSessionData"
  @type_add_slot "addSlot"

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
  def call(_client, _type, _payload), do: @invalid_request
end

defmodule ResoniteLinkEx.Scene do
  @moduledoc """
  ResoniteLink 命令呼び出しの入口API。
  """

  @invalid_request {:error, :invalid_request}
  @not_implemented {:error, :not_implemented}

  @doc """
  指定した `$type` と `payload` で命令を呼び出す。
  """
  @spec call(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(_client, type, _payload) when not is_binary(type), do: @invalid_request
  def call(_client, _type, payload) when not is_map(payload), do: @invalid_request

  def call(_client, "requestSessionData", payload) when map_size(payload) == 0,
    do: @not_implemented

  def call(_client, "requestSessionData", _payload), do: @invalid_request

  def call(_client, "addSlot", %{parent_id: _parent_id, name: _name}),
    do: @not_implemented

  def call(_client, "addSlot", _payload), do: @invalid_request
  def call(_client, _type, _payload), do: @invalid_request
end

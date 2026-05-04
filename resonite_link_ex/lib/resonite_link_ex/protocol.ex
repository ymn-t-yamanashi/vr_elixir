defmodule ResoniteLinkEx.Protocol do
  @moduledoc """
  ResoniteLink 送受信フォーマットを扱うモジュール。
  """

  @types [
    "requestSessionData",
    "addSlot",
    "updateSlot",
    "addComponent",
    "updateComponent",
    "removeComponent",
    "removeSlot"
  ]

  @spec valid_type?(String.t()) :: boolean()
  def valid_type?(type) when is_binary(type) do
    type in @types
  end

  def valid_type?(_type), do: false
end

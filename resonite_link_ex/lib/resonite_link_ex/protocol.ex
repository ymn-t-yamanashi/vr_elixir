defmodule ResoniteLinkEx.Protocol do
  @moduledoc """
  ResoniteLink 送受信フォーマットを扱うモジュール。
  """

  # スプリント1で送信を許可する ResoniteLink の `$type` 一覧。
  @types [
    # セッション情報を取得する
    "requestSessionData",
    # Slot を新規作成する
    "addSlot",
    # 既存 Slot を更新する
    "updateSlot",
    # Slot に Component を追加する
    "addComponent",
    # 既存 Component を更新する
    "updateComponent",
    # Component を削除する
    "removeComponent",
    # Slot を削除する
    "removeSlot"
  ]

  @doc """
  送信可能な `$type` かどうかを返す。
  """
  @spec valid_type?(String.t()) :: boolean()
  def valid_type?(type) when is_binary(type) do
    type in @types
  end

  def valid_type?(_type), do: false
end

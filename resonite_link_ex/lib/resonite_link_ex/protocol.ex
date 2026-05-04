defmodule ResoniteLinkEx.Protocol do
  @moduledoc """
  ResoniteLink 送受信フォーマットを扱うモジュール。
  """

  @invalid_request {:error, :invalid_request}
  @type_request_session_data "requestSessionData"
  @type_add_slot "addSlot"
  @type_update_slot "updateSlot"
  @type_add_component "addComponent"
  @type_update_component "updateComponent"
  @type_remove_component "removeComponent"
  @type_remove_slot "removeSlot"

  # スプリント1で送信を許可する ResoniteLink の `$type` 一覧。
  @types [
    # セッション情報を取得する
    @type_request_session_data,
    # Slot を新規作成する
    @type_add_slot,
    # 既存 Slot を更新する
    @type_update_slot,
    # Slot に Component を追加する
    @type_add_component,
    # 既存 Component を更新する
    @type_update_component,
    # Component を削除する
    @type_remove_component,
    # Slot を削除する
    @type_remove_slot
  ]

  @doc """
  送信可能な `$type` かどうかを返す。
  """
  @spec valid_type?(String.t()) :: boolean()
  def valid_type?(type) when is_binary(type) do
    type in @types
  end

  def valid_type?(_type), do: false

  @doc """
  `$type` ごとの payload を検証する。
  """
  @spec validate_payload(String.t(), map()) :: {:ok, map()} | {:error, :invalid_request}
  def validate_payload(@type_request_session_data, payload) when payload == %{} do
    {:ok, payload}
  end

  def validate_payload(@type_add_slot, %{parent_id: _parent_id, name: _name} = payload) do
    {:ok, payload}
  end

  def validate_payload(@type_update_slot, %{slot_id: _slot_id} = payload) do
    if has_update_slot_field?(payload) do
      {:ok, payload}
    else
      @invalid_request
    end
  end

  def validate_payload(@type_add_component, %{slot_id: _slot_id, component_type: _type} = payload) do
    {:ok, payload}
  end

  def validate_payload(
        @type_update_component,
        %{component_id: _component_id, members: members} = payload
      )
      when is_map(members) do
    {:ok, payload}
  end

  def validate_payload(@type_remove_component, %{component_id: _component_id} = payload) do
    {:ok, payload}
  end

  def validate_payload(@type_remove_slot, %{slot_id: _slot_id} = payload) do
    {:ok, payload}
  end

  def validate_payload(_type, _payload) do
    @invalid_request
  end

  defp has_update_slot_field?(payload) do
    Enum.any?([:position, :rotation, :scale, :name], &Map.has_key?(payload, &1))
  end
end

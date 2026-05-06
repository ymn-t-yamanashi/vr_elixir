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
  @type_get_slot "getSlot"

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
    @type_remove_slot,
    # Slot 情報を取得する
    @type_get_slot
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
    if has_update_slot_field?(payload), do: {:ok, payload}, else: @invalid_request
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

  def validate_payload(@type_get_slot, %{slot_id: _slot_id} = payload) do
    {:ok, payload}
  end

  def validate_payload(_type, _payload) do
    @invalid_request
  end

  @doc """
  送信用リクエスト map（`$type` と `data`）を生成する。
  """
  @spec encode_request(String.t(), map()) :: {:ok, map()} | {:error, :invalid_request}
  def encode_request(type, payload) do
    with true <- valid_type?(type),
         {:ok, validated_payload} <- validate_payload(type, payload) do
      {:ok, %{"messageId" => generate_message_id(), "$type" => type, "data" => validated_payload}}
    else
      _ -> @invalid_request
    end
  end

  @doc """
  送信直前に ResoniteLink 仕様（camelCase）へ変換したリクエスト map を生成する。
  """
  @spec encode_transport_request(String.t(), map()) :: {:ok, map()} | {:error, :invalid_request}
  def encode_transport_request(type, payload) do
    with {:ok, request} <- encode_request(type, payload) do
      {:ok, Map.update!(request, "data", &to_transport_payload(type, &1))}
    end
  end

  @doc """
  受信レスポンスを検証して返す。
  """
  @spec decode_response(map()) :: {:ok, map()} | {:error, :decode_error}
  def decode_response(%{"sourceMessageId" => source_message_id} = response)
      when is_binary(source_message_id),
      do: {:ok, Map.put(response, "messageId", source_message_id)}

  def decode_response(%{"messageId" => message_id} = response) when is_binary(message_id),
    do: {:ok, response}

  def decode_response(response) when is_map(response), do: {:error, :decode_error}
  def decode_response(_response), do: {:error, :decode_error}

  @doc """
  リクエスト対応付けに使う `UUID v4` 文字列を生成する。
  """
  @spec generate_message_id() :: String.t()
  def generate_message_id, do: UUID.uuid4()

  defp has_update_slot_field?(payload) do
    Enum.any?([:position, :rotation, :scale, :name], &Map.has_key?(payload, &1))
  end

  defp to_transport_payload(@type_add_slot, payload) do
    payload
    |> rename_key(:parent_id, "parentId")
  end

  defp to_transport_payload(@type_update_slot, payload) do
    payload
    |> rename_key(:slot_id, "slotId")
  end

  defp to_transport_payload(@type_add_component, payload) do
    payload
    |> rename_key(:slot_id, "slotId")
    |> rename_key(:component_type, "componentType")
  end

  defp to_transport_payload(@type_update_component, payload) do
    payload
    |> rename_key(:component_id, "componentId")
  end

  defp to_transport_payload(@type_remove_component, payload) do
    payload
    |> rename_key(:component_id, "componentId")
  end

  defp to_transport_payload(@type_remove_slot, payload) do
    payload
    |> rename_key(:slot_id, "slotId")
  end

  defp to_transport_payload(@type_get_slot, payload) do
    payload
    |> rename_key(:slot_id, "slotId")
  end

  defp to_transport_payload(_type, payload), do: payload

  defp rename_key(payload, from_atom, to_string) do
    case Map.pop(payload, from_atom) do
      {nil, rest} -> rest
      {value, rest} -> Map.put(rest, to_string, value)
    end
  end
end

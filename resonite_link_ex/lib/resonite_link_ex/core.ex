defmodule ResoniteLinkEx.Core do
  @moduledoc """
  Resonite の基本コマンドを低レベルで扱うモジュールです。

  `requestSessionData` / `addSlot` / `updateSlot` など、`$type` 単位のAPIを提供します。
  `client` に接続済み PID を渡した場合は `ResoniteLinkEx.Client.call/3` 経由で送信を行います。
  PID 以外を渡した場合は「送信しやすい内部リクエスト形式」を返します。

  使い分けの目安:
  - 手早く使いたい: `ResoniteLinkEx`（公開入口）を使う
  - 細かく制御したい: 本モジュールを使う

  高い自由度と引き換えに、payload の妥当性を呼び出し側が意識する必要があります。
  """

  alias ResoniteLinkEx.Protocol

  @doc """
  セッション情報取得用の `requestSessionData` リクエストを作成する。

  ## Parameters
  - `client`: 呼び出し元ハンドル。現実装では未使用だが将来拡張のため受け取る。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正などで失敗。

  ## Examples
      iex> ResoniteLinkEx.Core.request_session_data(client)
      {:ok, _request}
  """
  @spec request_session_data(term()) :: {:ok, map()} | {:error, term()}
  def request_session_data(client), do: call_core(client, "requestSessionData", %{})

  @doc """
  新しいSlotを作るための `addSlot` リクエストを作成する。

  ## Parameters
  - `client`: 呼び出し元ハンドル。
  - `payload`: `%{parent_id: String.t(), name: String.t()}` を含む map。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正などで失敗。

  ## Examples
      iex> payload = %{parent_id: "Root", name: "BoxA"}
      iex> ResoniteLinkEx.Core.add_slot(client, payload)
      {:ok, _request}
  """
  @spec add_slot(term(), map()) :: {:ok, map()} | {:error, term()}
  def add_slot(client, payload), do: call_core(client, "addSlot", payload)

  @doc """
  既存Slotを更新するための `updateSlot` リクエストを作成する。

  ## Parameters
  - `client`: 呼び出し元ハンドル。
  - `payload`: `%{slot_id: String.t(), ...}` を含む更新 payload。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正などで失敗。

  ## Examples
      iex> payload = %{slot_id: "SlotA", position: %{x: 0, y: 1, z: 0}}
      iex> ResoniteLinkEx.Core.update_slot(client, payload)
      {:ok, _request}
  """
  @spec update_slot(term(), map()) :: {:ok, map()} | {:error, term()}
  def update_slot(client, payload), do: call_core(client, "updateSlot", payload)

  @doc """
  SlotにComponentを追加するための `addComponent` リクエストを作成する。

  ## Parameters
  - `client`: 呼び出し元ハンドル。
  - `payload`: `%{slot_id: String.t(), component_type: String.t()}` を含む map。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正などで失敗。

  ## Examples
      iex> payload = %{slot_id: "SlotA", component_type: "FrooxEngine.BoxCollider"}
      iex> ResoniteLinkEx.Core.add_component(client, payload)
      {:ok, _request}
  """
  @spec add_component(term(), map()) :: {:ok, map()} | {:error, term()}
  def add_component(client, payload), do: call_core(client, "addComponent", payload)

  @doc """
  既存Componentを更新するための `updateComponent` リクエストを作成する。

  ## Parameters
  - `client`: 呼び出し元ハンドル。
  - `payload`: `%{component_id: String.t(), members: map()}` を含む map。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正などで失敗。

  ## Examples
      iex> payload = %{component_id: "CompA", members: %{"Enabled" => true}}
      iex> ResoniteLinkEx.Core.update_component(client, payload)
      {:ok, _request}
  """
  @spec update_component(term(), map()) :: {:ok, map()} | {:error, term()}
  def update_component(client, payload), do: call_core(client, "updateComponent", payload)

  @doc """
  Componentを削除するための `removeComponent` リクエストを作成する。

  ## Parameters
  - `client`: 呼び出し元ハンドル。
  - `payload`: `%{component_id: String.t()}` を含む map。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正などで失敗。

  ## Examples
      iex> payload = %{component_id: "CompA"}
      iex> ResoniteLinkEx.Core.remove_component(client, payload)
      {:ok, _request}
  """
  @spec remove_component(term(), map()) :: {:ok, map()} | {:error, term()}
  def remove_component(client, payload), do: call_core(client, "removeComponent", payload)

  @doc """
  Slotを削除するための `removeSlot` リクエストを作成する。

  ## Parameters
  - `client`: 呼び出し元ハンドル。
  - `payload`: `%{slot_id: String.t()}` を含む map。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正などで失敗。

  ## Examples
      iex> payload = %{slot_id: "SlotA"}
      iex> ResoniteLinkEx.Core.remove_slot(client, payload)
      {:ok, _request}
  """
  @spec remove_slot(term(), map()) :: {:ok, map()} | {:error, term()}
  def remove_slot(client, payload), do: call_core(client, "removeSlot", payload)

  @doc """
  Slot情報を取得するための `getSlot` リクエストを作成する。

  ## Parameters
  - `client`: 呼び出し元ハンドル。
  - `payload`: `%{slot_id: String.t()}` を含む map。

  ## Returns
  - `{:ok, map()}`: リクエスト生成成功。
  - `{:error, term()}`: 入力不正などで失敗。

  ## Examples
      iex> payload = %{slot_id: "SlotA"}
      iex> ResoniteLinkEx.Core.get_slot(client, payload)
      {:ok, _request}
  """
  @spec get_slot(term(), map()) :: {:ok, map()} | {:error, term()}
  def get_slot(client, payload), do: call_core(client, "getSlot", payload)

  defp call_core(_client, type, _payload) when not is_binary(type), do: {:error, :invalid_request}
  defp call_core(_client, _type, payload) when not is_map(payload), do: {:error, :invalid_request}

  defp call_core(client, type, payload) when is_pid(client) do
    ResoniteLinkEx.Client.call(client, type, payload)
  end

  defp call_core(_client, type, payload) do
    case Protocol.encode_request(type, payload) do
      {:ok, %{"$type" => encoded_type, "data" => encoded_payload}} ->
        {:ok, %{type: encoded_type, payload: encoded_payload}}

      _ ->
        {:error, :invalid_request}
    end
  end
end

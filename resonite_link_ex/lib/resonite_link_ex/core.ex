defmodule ResoniteLinkEx.Core do
  @moduledoc """
  ResoniteLink の基礎コマンドを直接呼び出す低レイヤ API。

  `ResoniteLinkEx` がユースケース向け API を提供するのに対して、
  本モジュールは `$type` 単位で薄く呼び出す用途を想定する。
  """

  alias ResoniteLinkEx.Scene

  @doc """
  `requestSessionData` を呼び出す。

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
  def request_session_data(client), do: Scene.call(client, "requestSessionData", %{})

  @doc """
  `addSlot` を呼び出す。

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
  def add_slot(client, payload), do: Scene.call(client, "addSlot", payload)

  @doc """
  `updateSlot` を呼び出す。

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
  def update_slot(client, payload), do: Scene.call(client, "updateSlot", payload)

  @doc """
  `addComponent` を呼び出す。

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
  def add_component(client, payload), do: Scene.call(client, "addComponent", payload)

  @doc """
  `updateComponent` を呼び出す。

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
  def update_component(client, payload), do: Scene.call(client, "updateComponent", payload)

  @doc """
  `removeComponent` を呼び出す。

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
  def remove_component(client, payload), do: Scene.call(client, "removeComponent", payload)

  @doc """
  `removeSlot` を呼び出す。

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
  def remove_slot(client, payload), do: Scene.call(client, "removeSlot", payload)

  @doc """
  `getSlot` を呼び出す。

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
  def get_slot(client, payload), do: Scene.call(client, "getSlot", payload)
end

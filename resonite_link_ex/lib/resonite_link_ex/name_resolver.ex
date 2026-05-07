defmodule ResoniteLinkEx.NameResolver do
  @moduledoc """
  オブジェクト名（`name`）から実ID（`slot_id`）を解決するモジュールです。

  名前指定APIでは最終的に `slot_id` が必要になるため、その橋渡しを行います。
  このモジュールは次を担当します。
  - 名前一致する候補スロット一覧の取得
  - 同名が複数ある場合の絞り込み（`parent_name` 条件）
  - 最終的に `getSlot` で存在確認

  返り値は `{:ok, slot_id}` または `{:error, reason}` で統一されており、
  上位の `Objects` モジュールから利用される前提です。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Core

  @invalid_request {:error, :invalid_request}

  @doc """
  名前（必要なら親名条件つき）から、一意な `slot_id` を解決する。

  ## Parameters
  - `client`: `pid()` または同等の呼び出し対象。
  - `name`: 解決対象の名前。
  - `opts`: `find_slots_fun` などのオプション。

  ## Returns
  - `{:ok, String.t()}`: 解決成功した `slot_id`。
  - `{:error, :not_found | :ambiguous_name | :invalid_request | term()}`: 解決失敗。

  ## Examples
      find_slots_fun = fn _client, _name, _opts -> {:ok, [%{slot_id: "slot_a", name: "CubeA"}]} end
      get_slot_fun = fn _client, _slot_id -> {:ok, %{}} end
      ResoniteLinkEx.NameResolver.resolve_slot_id(:client, "CubeA", find_slots_fun: find_slots_fun, get_slot_fun: get_slot_fun)
      {:ok, "slot_a"}
  """
  @spec resolve_slot_id(term(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, :not_found | :ambiguous_name | :invalid_request | term()}
  def resolve_slot_id(client, name, opts \\ [])

  def resolve_slot_id(_client, name, _opts)
      when not is_binary(name) or name == "",
      do: @invalid_request

  def resolve_slot_id(_client, _name, opts) when not is_list(opts),
    do: @invalid_request

  def resolve_slot_id(client, name, opts) do
    with {:ok, slots} <- fetch_slots(client, name, opts),
         {:ok, slot_id} <- select_slot_id(slots, Keyword.get(opts, :parent_name)),
         :ok <- verify_slot_exists(client, slot_id, opts) do
      {:ok, slot_id}
    end
  end

  defp fetch_slots(client, name, opts) do
    case Keyword.get(opts, :find_slots_fun) do
      find_slots_fun when is_function(find_slots_fun, 3) ->
        find_slots_fun.(client, name, opts)

      _other ->
        @invalid_request
    end
  end

  defp select_slot_id(slots, parent_name) when is_list(slots) do
    case Enum.filter(slots, &name_slot?/1) do
      [] ->
        {:error, :not_found}

      [slot] ->
        {:ok, slot.slot_id}

      many_slots ->
        pick_by_parent(many_slots, parent_name)
    end
  end

  defp select_slot_id(_slots, _parent_name), do: @invalid_request

  defp name_slot?(%{slot_id: slot_id, name: name}) when is_binary(slot_id) and is_binary(name),
    do: true

  defp name_slot?(_other), do: false

  defp pick_by_parent(_slots, nil), do: {:error, :ambiguous_name}

  defp pick_by_parent(slots, parent_name) when is_binary(parent_name) and parent_name != "" do
    filtered = Enum.filter(slots, &(Map.get(&1, :parent_name) == parent_name))

    case filtered do
      [slot] -> {:ok, slot.slot_id}
      [] -> {:error, :not_found}
      _many -> {:error, :ambiguous_name}
    end
  end

  defp pick_by_parent(_slots, _parent_name), do: @invalid_request

  defp verify_slot_exists(client, slot_id, opts) do
    get_slot_fun = Keyword.get(opts, :get_slot_fun, &default_get_slot/2)

    if is_function(get_slot_fun, 2) do
      case get_slot_fun.(client, slot_id) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      @invalid_request
    end
  end

  defp default_get_slot(client, slot_id) do
    case Client.client_pid(client) do
      {:ok, client_pid} ->
        request = %{"messageId" => UUID.uuid4(), "$type" => "getSlot", "slotId" => slot_id}

        with :ok <- Client.register_pending(client_pid, request["messageId"], self()),
             :ok <- Client.send_json(client, request),
             do: {:ok, request}

      {:error, :invalid_request} ->
        Core.get_slot(client, %{slot_id: slot_id})
    end
  end
end

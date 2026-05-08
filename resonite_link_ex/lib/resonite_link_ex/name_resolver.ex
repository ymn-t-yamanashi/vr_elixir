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
  @request_timeout_ms 1_500

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
        default_find_slots(client, name, opts)
    end
  end

  defp default_find_slots(client, name, opts) do
    timeout_ms = Keyword.get(opts, :timeout_ms, @request_timeout_ms)
    debug? = Keyword.get(opts, :debug, false)
    parent_name = Keyword.get(opts, :parent_name)

    case fetch_root_slot_id(client, timeout_ms) do
      {:ok, root_slot_id} ->
        walk_slots(client, [root_slot_id], name, timeout_ms, [], debug?, parent_name)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_root_slot_id(client, timeout_ms) do
    case request_over_transport(client, "requestSessionData", %{}, timeout_ms) do
      {:ok, response} ->
        extract_root_slot_id(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp walk_slots(_client, [], _target_name, _timeout_ms, acc, _debug?, _parent_name),
    do: {:ok, Enum.reverse(acc)}

  defp walk_slots(client, [slot_id | rest], target_name, timeout_ms, acc, debug?, parent_name) do
    if debug?, do: IO.puts("[NameResolver] visiting slot_id=#{slot_id}")

    with {:ok, response} <-
           request_over_transport(client, "getSlot", %{"slotId" => slot_id}, timeout_ms),
         {:ok, slot_name, parent_name, child_ids} <- extract_slot_info(response, slot_id) do
      if debug?,
        do:
          IO.puts("[NameResolver] slot name=#{inspect(slot_name)} children=#{length(child_ids)}")

      next_acc =
        if slot_name == target_name do
          [%{slot_id: slot_id, name: slot_name, parent_name: parent_name} | acc]
        else
          acc
        end

      if can_stop_early?(next_acc, parent_name) do
        {:ok, Enum.reverse(next_acc)}
      else
        walk_slots(
          client,
          rest ++ child_ids,
          target_name,
          timeout_ms,
          next_acc,
          debug?,
          parent_name
        )
      end
    else
      {:error, :not_found} ->
        if debug?, do: IO.puts("[NameResolver] slot not found: #{slot_id}")
        walk_slots(client, rest, target_name, timeout_ms, acc, debug?, parent_name)

      {:error, reason} ->
        if debug?, do: IO.puts("[NameResolver] request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp can_stop_early?([_first | _rest], nil), do: true
  defp can_stop_early?(_matches, _parent_name), do: false

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

  defp request_over_transport(client, type, data, timeout_ms)
       when is_pid(client) and is_binary(type) and is_map(data) do
    request = build_transport_request(type, data)

    with {:ok, client_pid} <- Client.client_pid(client),
         :ok <- Client.register_pending(client_pid, request["messageId"], self()),
         :ok <- Client.send_json(client, request) do
      await_response(client_pid, request["messageId"], timeout_ms)
    end
  end

  defp request_over_transport(_client, _type, _data, _timeout_ms), do: @invalid_request

  defp build_transport_request("getSlot", %{"slotId" => slot_id}) when is_binary(slot_id) do
    %{"messageId" => UUID.uuid4(), "$type" => "getSlot", "slotId" => slot_id}
  end

  defp build_transport_request("requestSessionData", data) when is_map(data) do
    %{"messageId" => UUID.uuid4(), "$type" => "requestSessionData", "data" => data}
  end

  defp build_transport_request(type, data) do
    %{"messageId" => UUID.uuid4(), "$type" => type, "data" => data}
  end

  defp await_response(client_pid, message_id, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_response(client_pid, message_id, deadline)
  end

  defp do_await_response(client_pid, message_id, deadline) do
    case Client.last_response(client_pid) do
      %{"messageId" => ^message_id} = response ->
        {:ok, response}

      _other ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, :request_timeout}
        else
          Process.sleep(20)
          do_await_response(client_pid, message_id, deadline)
        end
    end
  end

  defp extract_root_slot_id(%{"data" => data}) when is_map(data) do
    root_slot_id =
      Map.get(data, "rootSlotId") ||
        Map.get(data, "rootSlotID") ||
        Map.get(data, "rootSlot") ||
        get_in(data, ["session", "rootSlotId"]) ||
        get_in(data, ["session", "rootSlotID"])

    if is_binary(root_slot_id) and root_slot_id != "" do
      {:ok, root_slot_id}
    else
      {:ok, "Root"}
    end
  end

  defp extract_root_slot_id(_response), do: {:ok, "Root"}

  defp extract_slot_info(response, _fallback_slot_id) do
    data = Map.get(response, "data", %{})

    slot_name =
      data
      |> pick_value([
        ["name"],
        ["Name"],
        ["slot", "name"],
        ["slot", "Name"],
        ["slot", "SlotName"],
        ["slotName"],
        ["SlotName"]
      ])
      |> normalize_name_value()

    parent_name =
      pick_value(data, [
        ["parentName"],
        ["ParentName"],
        ["parent", "name"],
        ["parent", "Name"],
        ["slot", "parentName"],
        ["slot", "ParentName"]
      ])

    child_ids = extract_child_slot_ids(data)

    {:ok, slot_name, parent_name, child_ids}
  end

  defp extract_child_slot_ids(data) when is_map(data) do
    raw_children = pick_children(data)

    raw_children
    |> List.wrap()
    |> Enum.map(fn
      %{"slotId" => id} when is_binary(id) -> id
      %{"SlotId" => id} when is_binary(id) -> id
      %{"id" => id} when is_binary(id) -> id
      %{"Id" => id} when is_binary(id) -> id
      %{"ID" => id} when is_binary(id) -> id
      %{"id" => id} when is_binary(id) -> id
      %{slot_id: id} when is_binary(id) -> id
      %{id: id} when is_binary(id) -> id
      id when is_binary(id) -> id
      _other -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp pick_children(data) do
    pick_value(data, [
      ["children"],
      ["Children"],
      ["childSlots"],
      ["ChildSlots"],
      ["slots"],
      ["Slots"],
      ["slot", "children"],
      ["slot", "Children"],
      ["slot", "childSlots"],
      ["slot", "ChildSlots"],
      ["slot", "slots"],
      ["slot", "Slots"]
    ]) || []
  end

  defp pick_value(data, paths) when is_map(data) and is_list(paths) do
    Enum.find_value(paths, fn path -> get_in(data, path) end)
  end

  defp normalize_name_value(value) when is_binary(value), do: value
  defp normalize_name_value(%{"value" => value}) when is_binary(value), do: value
  defp normalize_name_value(%{value: value}) when is_binary(value), do: value
  defp normalize_name_value(_value), do: nil
end

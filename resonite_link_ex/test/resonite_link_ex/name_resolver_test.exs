defmodule ResoniteLinkEx.NameResolverTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.NameResolver

  test "resolve_slot_id/3 は一意な name を解決できる" do
    find_slots_fun = fn _client, "CubeA", _opts ->
      {:ok, [%{slot_id: "slot_a", name: "CubeA"}]}
    end

    get_slot_fun = fn _client, "slot_a" ->
      {:ok, %{type: "getSlot", payload: %{slot_id: "slot_a"}}}
    end

    assert {:ok, "slot_a"} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               find_slots_fun: find_slots_fun,
               get_slot_fun: get_slot_fun
             )
  end

  test "resolve_slot_id/3 は候補なしで not_found を返す" do
    find_slots_fun = fn _client, _name, _opts -> {:ok, []} end

    assert {:error, :not_found} =
             NameResolver.resolve_slot_id(:client, "Missing", find_slots_fun: find_slots_fun)
  end

  test "resolve_slot_id/3 は同名複数で parent_name 未指定なら ambiguous_name を返す" do
    slots = [%{slot_id: "slot_a", name: "CubeA"}, %{slot_id: "slot_b", name: "CubeA"}]
    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    assert {:error, :ambiguous_name} =
             NameResolver.resolve_slot_id(:client, "CubeA", find_slots_fun: find_slots_fun)
  end

  test "resolve_slot_id/3 は parent_name 指定で1件に絞れれば解決できる" do
    slots = [
      %{slot_id: "slot_a", name: "CubeA", parent_name: "ParentA"},
      %{slot_id: "slot_b", name: "CubeA", parent_name: "ParentB"}
    ]

    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    get_slot_fun = fn _client, "slot_b" ->
      {:ok, %{type: "getSlot", payload: %{slot_id: "slot_b"}}}
    end

    assert {:ok, "slot_b"} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               parent_name: "ParentB",
               find_slots_fun: find_slots_fun,
               get_slot_fun: get_slot_fun
             )
  end

  test "resolve_slot_id/3 は getSlot 検証失敗時にエラーを返す" do
    find_slots_fun = fn _client, _name, _opts -> {:ok, [%{slot_id: "slot_a", name: "CubeA"}]} end
    get_slot_fun = fn _client, _slot_id -> {:error, :not_found} end

    assert {:error, :not_found} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               find_slots_fun: find_slots_fun,
               get_slot_fun: get_slot_fun
             )
  end

  test "resolve_slot_id/3 は不正入力で invalid_request を返す" do
    assert {:error, :invalid_request} = NameResolver.resolve_slot_id(:client, "", [])
    assert {:error, :invalid_request} = NameResolver.resolve_slot_id(:client, :name, [])
    assert {:error, :invalid_request} = NameResolver.resolve_slot_id(:client, "CubeA", :bad_opts)

    assert {:error, :invalid_request} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               get_slot_fun: fn _, _ -> {:ok, %{}} end
             )
  end

  test "resolve_slot_id/3 は不正な slot 要素を除外し not_found を返す" do
    find_slots_fun = fn _client, _name, _opts ->
      {:ok, [%{slot_id: "slot_a"}, %{name: "CubeA"}, %{slot_id: 1, name: "CubeA"}]}
    end

    assert {:error, :not_found} =
             NameResolver.resolve_slot_id(:client, "CubeA", find_slots_fun: find_slots_fun)
  end

  test "resolve_slot_id/3 は parent_name で絞り込み不可なら not_found を返す" do
    slots = [
      %{slot_id: "slot_a", name: "CubeA", parent_name: "ParentA"},
      %{slot_id: "slot_b", name: "CubeA", parent_name: "ParentB"}
    ]

    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    assert {:error, :not_found} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               parent_name: "ParentC",
               find_slots_fun: find_slots_fun
             )
  end

  test "resolve_slot_id/3 は parent_name 絞り込み後も複数なら ambiguous_name を返す" do
    slots = [
      %{slot_id: "slot_a", name: "CubeA", parent_name: "ParentA"},
      %{slot_id: "slot_b", name: "CubeA", parent_name: "ParentA"}
    ]

    find_slots_fun = fn _client, _name, _opts -> {:ok, slots} end

    assert {:error, :ambiguous_name} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               parent_name: "ParentA",
               find_slots_fun: find_slots_fun
             )
  end

  test "resolve_slot_id/3 は get_slot_fun が2引数関数でない場合 invalid_request を返す" do
    find_slots_fun = fn _client, _name, _opts -> {:ok, [%{slot_id: "slot_a", name: "CubeA"}]} end

    assert {:error, :invalid_request} =
             NameResolver.resolve_slot_id(:client, "CubeA",
               find_slots_fun: find_slots_fun,
               get_slot_fun: fn _slot_id -> {:ok, %{}} end
             )
  end
end

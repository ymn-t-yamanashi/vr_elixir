defmodule ResoniteLinkEx.ObjectsTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Objects

  test "move_slot_by_name/4 は name 解決後に updateSlot を返す" do
    assert {:ok, client} = ResoniteLinkEx.start_client()
    resolver = fn _client, "CubeA", _opts -> {:ok, "slot_a"} end
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:ok, %{"$type" => "updateSlot", "data" => %{slot_id: "slot_a", position: ^position}}} =
             Objects.move_slot_by_name(client, "CubeA", position, resolve_slot_id_fun: resolver)
  end

  test "delete_slot_by_name/3 は name 解決後に removeSlot を返す" do
    assert {:ok, client} = ResoniteLinkEx.start_client()
    resolver = fn _client, "CubeA", _opts -> {:ok, "slot_a"} end

    assert {:ok, %{"$type" => "removeSlot", "data" => %{slot_id: "slot_a"}}} =
             Objects.delete_slot_by_name(client, "CubeA", resolve_slot_id_fun: resolver)
  end

  test "move_slot_by_name/4 は resolver のエラーを返す" do
    resolver = fn _client, _name, _opts -> {:error, :ambiguous_name} end
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:error, :ambiguous_name} =
             Objects.move_slot_by_name(:client, "CubeA", position, resolve_slot_id_fun: resolver)
  end

  test "delete_slot_by_name/3 は resolver のエラーを返す" do
    resolver = fn _client, _name, _opts -> {:error, :not_found} end

    assert {:error, :not_found} =
             Objects.delete_slot_by_name(:client, "CubeA", resolve_slot_id_fun: resolver)
  end

  test "move_slot/3 は slot_id 指定で updateSlot を返す" do
    assert {:ok, client} = ResoniteLinkEx.start_client()
    position = %{"x" => 1, "y" => 2, "z" => 3}

    assert {:ok, %{"$type" => "updateSlot", "data" => %{slot_id: "slot_a", position: ^position}}} =
             Objects.move_slot(client, "slot_a", position)
  end

  test "delete_slot/2 は slot_id 指定で removeSlot を返す" do
    assert {:ok, client} = ResoniteLinkEx.start_client()

    assert {:ok, %{"$type" => "removeSlot", "data" => %{slot_id: "slot_a"}}} =
             Objects.delete_slot(client, "slot_a")
  end

  test "Objects API は不正入力で invalid_request を返す" do
    resolver = fn _client, _name, _opts -> {:ok, "slot_a"} end

    assert {:error, :invalid_request} = Objects.move_slot_by_name(:client, "", %{}, [])

    assert {:error, :invalid_request} =
             Objects.move_slot_by_name(:client, "CubeA", %{"x" => 1, "y" => 2},
               resolve_slot_id_fun: resolver
             )

    assert {:error, :invalid_request} = Objects.delete_slot_by_name(:client, :bad, [])

    assert {:error, :invalid_request} =
             Objects.move_slot(:client, "", %{"x" => 1, "y" => 2, "z" => 3})

    assert {:error, :invalid_request} = Objects.delete_slot(:client, "")
  end
end

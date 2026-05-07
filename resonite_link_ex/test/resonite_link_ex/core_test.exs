defmodule ResoniteLinkEx.CoreTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Core

  test "request_session_data/1 は requestSessionData を呼び出す" do
    assert {:ok, %{type: "requestSessionData", payload: %{}}} =
             Core.request_session_data(:client)
  end

  test "add_slot/2 は addSlot を呼び出す" do
    payload = %{parent_id: "Root", name: "BoxA"}
    assert {:ok, %{type: "addSlot", payload: ^payload}} = Core.add_slot(:client, payload)
  end

  test "update_slot/2 は updateSlot を呼び出す" do
    payload = %{slot_id: "SlotA", position: %{x: 0, y: 1, z: 0}}
    assert {:ok, %{type: "updateSlot", payload: ^payload}} = Core.update_slot(:client, payload)
  end

  test "add_component/2 は addComponent を呼び出す" do
    payload = %{slot_id: "SlotA", component_type: "FrooxEngine.BoxCollider"}

    assert {:ok, %{type: "addComponent", payload: ^payload}} =
             Core.add_component(:client, payload)
  end

  test "update_component/2 は updateComponent を呼び出す" do
    payload = %{component_id: "CompA", members: %{"Enabled" => true}}

    assert {:ok, %{type: "updateComponent", payload: ^payload}} =
             Core.update_component(:client, payload)
  end

  test "remove_component/2 は removeComponent を呼び出す" do
    payload = %{component_id: "CompA"}

    assert {:ok, %{type: "removeComponent", payload: ^payload}} =
             Core.remove_component(:client, payload)
  end

  test "remove_slot/2 は removeSlot を呼び出す" do
    payload = %{slot_id: "SlotA"}
    assert {:ok, %{type: "removeSlot", payload: ^payload}} = Core.remove_slot(:client, payload)
  end

  test "get_slot/2 は getSlot を呼び出す" do
    payload = %{slot_id: "SlotA"}
    assert {:ok, %{type: "getSlot", payload: ^payload}} = Core.get_slot(:client, payload)
  end

  test "各APIは payload 型不正で invalid_request を返す" do
    assert {:error, :invalid_request} = Core.add_slot(:client, :bad)
    assert {:error, :invalid_request} = Core.update_slot(:client, :bad)
    assert {:error, :invalid_request} = Core.add_component(:client, :bad)
    assert {:error, :invalid_request} = Core.update_component(:client, :bad)
    assert {:error, :invalid_request} = Core.remove_component(:client, :bad)
    assert {:error, :invalid_request} = Core.remove_slot(:client, :bad)
    assert {:error, :invalid_request} = Core.get_slot(:client, :bad)
  end
end

defmodule ResoniteLinkEx.SceneTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Scene

  test "call/3 は requestSessionData の正常入力で ok を返す" do
    assert {:ok, %{type: "requestSessionData", payload: %{}}} =
             Scene.call(:client, "requestSessionData", %{})
  end

  test "call/3 は許可リスト外の type で invalid_request を返す" do
    assert {:error, :invalid_request} = Scene.call(:client, "unknownType", %{})
  end

  test "call/3 は payload が map 以外なら invalid_request を返す" do
    assert {:error, :invalid_request} = Scene.call(:client, "requestSessionData", [])
  end

  test "call/3 は payload 検証NGなら invalid_request を返す" do
    assert {:error, :invalid_request} =
             Scene.call(:client, "requestSessionData", %{unexpected: true})
  end

  test "call/3 は addSlot の必須キーが揃っていれば ok を返す" do
    payload = %{parent_id: "Root", name: "BoxA"}
    assert {:ok, %{type: "addSlot", payload: ^payload}} = Scene.call(:client, "addSlot", payload)
  end

  test "call/3 は addSlot の必須キー不足で invalid_request を返す" do
    assert {:error, :invalid_request} = Scene.call(:client, "addSlot", %{name: "BoxA"})
  end

  test "call/3 は type が文字列でない場合に invalid_request を返す" do
    assert {:error, :invalid_request} = Scene.call(:client, :add_slot, %{})
  end

  test "call/3 は updateSlot の必須条件が揃っていれば ok を返す" do
    payload = %{slot_id: "SlotA", position: %{x: 0, y: 1, z: 0}}

    assert {:ok, %{type: "updateSlot", payload: ^payload}} =
             Scene.call(:client, "updateSlot", payload)
  end

  test "call/3 は addComponent の必須条件が揃っていれば ok を返す" do
    payload = %{slot_id: "SlotA", component_type: "FrooxEngine.BoxCollider"}

    assert {:ok, %{type: "addComponent", payload: ^payload}} =
             Scene.call(:client, "addComponent", payload)
  end

  test "call/3 は addComponent の必須条件不足で invalid_request を返す" do
    payload = %{slot_id: "SlotA"}
    assert {:error, :invalid_request} = Scene.call(:client, "addComponent", payload)
  end

  test "call/3 は updateComponent の必須条件が揃っていれば ok を返す" do
    payload = %{component_id: "CompA", members: %{"Enabled" => true}}

    assert {:ok, %{type: "updateComponent", payload: ^payload}} =
             Scene.call(:client, "updateComponent", payload)
  end

  test "call/3 は updateComponent の必須条件不足で invalid_request を返す" do
    payload = %{component_id: "CompA"}
    assert {:error, :invalid_request} = Scene.call(:client, "updateComponent", payload)
  end

  test "call/3 は removeComponent の必須条件が揃っていれば ok を返す" do
    payload = %{component_id: "CompA"}

    assert {:ok, %{type: "removeComponent", payload: ^payload}} =
             Scene.call(:client, "removeComponent", payload)
  end

  test "call/3 は removeComponent の必須条件不足で invalid_request を返す" do
    assert {:error, :invalid_request} = Scene.call(:client, "removeComponent", %{})
  end

  test "call/3 は removeSlot の必須条件が揃っていれば ok を返す" do
    payload = %{slot_id: "SlotA"}

    assert {:ok, %{type: "removeSlot", payload: ^payload}} =
             Scene.call(:client, "removeSlot", payload)
  end

  test "call/3 は removeSlot の必須条件不足で invalid_request を返す" do
    assert {:error, :invalid_request} = Scene.call(:client, "removeSlot", %{})
  end

  test "call/3 は updateSlot の必須条件不足で invalid_request を返す" do
    assert {:error, :invalid_request} = Scene.call(:client, "updateSlot", %{slot_id: "SlotA"})
  end

  test "call!/3 は正常入力で ok の値を返す" do
    payload = %{parent_id: "Root", name: "BoxA"}
    assert %{type: "addSlot", payload: ^payload} = Scene.call!(:client, "addSlot", payload)
  end

  test "call!/3 は不正入力で例外を送出する" do
    assert_raise RuntimeError, ~r/invalid_request/, fn ->
      Scene.call!(:client, "addSlot", %{name: "BoxA"})
    end
  end
end

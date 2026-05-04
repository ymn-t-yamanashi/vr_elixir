defmodule ResoniteLinkEx.ProtocolTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Protocol

  test "valid_type?/1 は対象コマンドで true を返す" do
    assert Protocol.valid_type?("requestSessionData")
    assert Protocol.valid_type?("addSlot")
    assert Protocol.valid_type?("updateSlot")
    assert Protocol.valid_type?("addComponent")
    assert Protocol.valid_type?("updateComponent")
    assert Protocol.valid_type?("removeComponent")
    assert Protocol.valid_type?("removeSlot")
  end

  test "valid_type?/1 は対象外コマンドで false を返す" do
    refute Protocol.valid_type?("unknownType")
  end

  test "valid_type?/1 は文字列以外で false を返す" do
    refute Protocol.valid_type?(:add_slot)
  end

  test "validate_payload/2 は requestSessionData で空 map を許可する" do
    assert {:ok, %{}} = Protocol.validate_payload("requestSessionData", %{})
  end

  test "validate_payload/2 は requestSessionData で非空 map を拒否する" do
    assert {:error, :invalid_request} =
             Protocol.validate_payload("requestSessionData", %{foo: "bar"})
  end

  test "validate_payload/2 は対応外 type を拒否する" do
    assert {:error, :invalid_request} = Protocol.validate_payload("addSlot", %{})
  end

  test "validate_payload/2 は addSlot の必須キーが揃っていれば許可する" do
    payload = %{parent_id: "Root", name: "BoxA"}
    assert {:ok, ^payload} = Protocol.validate_payload("addSlot", payload)
  end

  test "validate_payload/2 は addSlot の parent_id がなければ拒否する" do
    assert {:error, :invalid_request} =
             Protocol.validate_payload("addSlot", %{name: "BoxA"})
  end

  test "validate_payload/2 は addSlot の name がなければ拒否する" do
    assert {:error, :invalid_request} =
             Protocol.validate_payload("addSlot", %{parent_id: "Root"})
  end

  test "validate_payload/2 は updateSlot の必須条件を満たせば許可する" do
    payload = %{slot_id: "SlotA", position: %{x: 0, y: 1, z: 0}}
    assert {:ok, ^payload} = Protocol.validate_payload("updateSlot", payload)
  end

  test "validate_payload/2 は updateSlot で slot_id がなければ拒否する" do
    assert {:error, :invalid_request} =
             Protocol.validate_payload("updateSlot", %{position: %{x: 0, y: 1, z: 0}})
  end

  test "validate_payload/2 は updateSlot で更新項目がなければ拒否する" do
    assert {:error, :invalid_request} =
             Protocol.validate_payload("updateSlot", %{slot_id: "SlotA"})
  end

  test "validate_payload/2 は addComponent の必須キーが揃っていれば許可する" do
    payload = %{slot_id: "SlotA", component_type: "FrooxEngine.BoxCollider"}
    assert {:ok, ^payload} = Protocol.validate_payload("addComponent", payload)
  end

  test "validate_payload/2 は addComponent で必須キー不足なら拒否する" do
    assert {:error, :invalid_request} =
             Protocol.validate_payload("addComponent", %{slot_id: "SlotA"})
  end

  test "validate_payload/2 は updateComponent の必須キーが揃っていれば許可する" do
    payload = %{component_id: "CompA", members: %{"Enabled" => true}}
    assert {:ok, ^payload} = Protocol.validate_payload("updateComponent", payload)
  end

  test "validate_payload/2 は updateComponent で必須キー不足なら拒否する" do
    assert {:error, :invalid_request} =
             Protocol.validate_payload("updateComponent", %{component_id: "CompA"})
  end

  test "validate_payload/2 は removeComponent の component_id があれば許可する" do
    payload = %{component_id: "CompA"}
    assert {:ok, ^payload} = Protocol.validate_payload("removeComponent", payload)
  end

  test "validate_payload/2 は removeComponent で component_id がなければ拒否する" do
    assert {:error, :invalid_request} = Protocol.validate_payload("removeComponent", %{})
  end

  test "validate_payload/2 は removeSlot の slot_id があれば許可する" do
    payload = %{slot_id: "SlotA"}
    assert {:ok, ^payload} = Protocol.validate_payload("removeSlot", payload)
  end

  test "validate_payload/2 は removeSlot で slot_id がなければ拒否する" do
    assert {:error, :invalid_request} = Protocol.validate_payload("removeSlot", %{})
  end

  test "encode_request/2 は有効な入力なら送信用 map を返す" do
    payload = %{parent_id: "Root", name: "BoxA"}

    assert {:ok, %{"$type" => "addSlot", "data" => ^payload}} =
             Protocol.encode_request("addSlot", payload)
  end

  test "encode_request/2 は不正な入力なら invalid_request を返す" do
    assert {:error, :invalid_request} = Protocol.encode_request("addSlot", %{})
  end

  test "decode_response/1 は map をそのまま ok で返す" do
    response = %{"status" => "ok"}
    assert {:ok, ^response} = Protocol.decode_response(response)
  end

  test "decode_response/1 は map 以外なら decode_error を返す" do
    assert {:error, :decode_error} = Protocol.decode_response("not_map")
  end
end

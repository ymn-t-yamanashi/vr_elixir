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
end

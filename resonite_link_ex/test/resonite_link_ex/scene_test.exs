defmodule ResoniteLinkEx.SceneTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Scene

  test "call/3 は現時点で not_implemented を返す" do
    assert {:error, :not_implemented} = Scene.call(:client, "requestSessionData", %{})
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
end

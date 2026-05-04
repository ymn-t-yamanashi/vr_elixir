defmodule ResoniteLinkEx.SceneTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Scene

  test "call/3 は現時点で not_implemented を返す" do
    assert {:error, :not_implemented} = Scene.call(:client, "requestSessionData", %{})
  end
end

defmodule ResoniteLinkEx.ClientTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Client

  test "start_link/1 は現時点で not_implemented を返す" do
    assert {:error, :not_implemented} = Client.start_link([])
  end
end

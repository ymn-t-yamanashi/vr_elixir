defmodule ResoniteLinkEx.ClientTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Client

  test "start_link/1 はクライアントプロセスを起動できる" do
    assert {:ok, pid} = Client.start_link([])
    assert is_pid(pid)
    assert Process.alive?(pid)

    Process.exit(pid, :normal)
  end
end

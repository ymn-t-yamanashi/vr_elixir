defmodule ResoniteLinkEx.ClientTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Client

  test "start_link/1 はクライアントプロセスを起動できる" do
    assert {:ok, pid} = Client.start_link([])
    assert is_pid(pid)
    assert Process.alive?(pid)
    assert Client.connected?(pid)

    Process.exit(pid, :normal)
  end

  test "connected?/1 は停止済みプロセスで false を返す" do
    assert {:ok, pid} = Client.start_link([])
    Process.unlink(pid)
    Process.exit(pid, :shutdown)
    Process.sleep(10)

    refute Client.connected?(pid)
  end

  test "connected?/1 は pid 以外で false を返す" do
    refute Client.connected?(:not_pid)
  end
end

defmodule ResoniteLinkEx.PortDiscoveryTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.PortDiscovery

  test "find_resonite_link_port/1 は dotnet の 127.0.0.1:xxxx を検出する" do
    output = """
    LISTEN 0      500        127.0.0.1:42571      0.0.0.0:*    users:((\"dotnet\",pid=1,fd=1))
    LISTEN 0      500        127.0.0.1:33333      0.0.0.0:*    users:((\"other\",pid=2,fd=1))
    """

    fake_cmd = fn "ss", ["-ltnp"] -> {output, 0} end

    assert {:ok, 42_571} = PortDiscovery.find_resonite_link_port(fake_cmd, fn -> true end)
  end

  test "find_resonite_link_port/1 は候補がないと port_not_found を返す" do
    output = "LISTEN 0 128 127.0.0.1:12345 0.0.0.0:* users:((\"beam.smp\",pid=1,fd=1))"
    fake_cmd = fn "ss", ["-ltnp"] -> {output, 0} end

    assert {:error, :port_not_found} =
             PortDiscovery.find_resonite_link_port(fake_cmd, fn -> true end)
  end

  test "find_resonite_link_port/1 は不正ポート値を除外して port_not_found を返す" do
    output =
      "LISTEN 0 500 127.0.0.1:70000 0.0.0.0:* users:((\"dotnet\",pid=1,fd=1))"

    fake_cmd = fn "ss", ["-ltnp"] -> {output, 0} end

    assert {:error, :port_not_found} =
             PortDiscovery.find_resonite_link_port(fake_cmd, fn -> true end)
  end

  test "find_resonite_link_port/1 は数値でないポート値を除外して port_not_found を返す" do
    output =
      "LISTEN 0 500 127.0.0.1:abc 0.0.0.0:* users:((\"dotnet\",pid=1,fd=1))"

    fake_cmd = fn "ss", ["-ltnp"] -> {output, 0} end

    assert {:error, :port_not_found} =
             PortDiscovery.find_resonite_link_port(fake_cmd, fn -> true end)
  end

  test "find_resonite_link_port/1 はコマンド失敗で command_failed を返す" do
    fake_cmd = fn "ss", ["-ltnp"] -> {"", 1} end

    assert {:error, :command_failed} =
             PortDiscovery.find_resonite_link_port(fake_cmd, fn -> true end)
  end

  test "find_resonite_link_port/1 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} = PortDiscovery.find_resonite_link_port(:not_fun)
  end

  test "find_resonite_link_port/2 は ss がない場合に ss_not_found を返す" do
    fake_cmd = fn "ss", ["-ltnp"] -> {"", 0} end
    fake_ss_exists = fn -> false end

    assert {:error, :ss_not_found} =
             PortDiscovery.find_resonite_link_port(fake_cmd, fake_ss_exists)
  end

  test "find_resonite_link_port/2 は不正引数で invalid_request を返す" do
    assert {:error, :invalid_request} =
             PortDiscovery.find_resonite_link_port(:not_fun, fn -> true end)

    assert {:error, :invalid_request} =
             PortDiscovery.find_resonite_link_port(fn _, _ -> {"", 0} end, :not_fun)
  end
end

defmodule Sprint5NameResolverSample do
  @moduledoc """
  NameResolver を使って `ResoniteLinkEx` の slot_id を解決するサンプル。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.NameResolver

  @target_name "ResoniteLinkEx"

  def run do
    {:ok, transport} = Client.start_link()

    wait_session_ready(transport, 30)

    case NameResolver.resolve_slot_id(transport, @target_name) do
      {:ok, slot_id} ->
        IO.puts("name=#{@target_name} slot_id=#{slot_id}")
        :ok

      {:error, reason} ->
        raise "解決に失敗しました: #{inspect(reason)}"
    end
  end

  defp wait_session_ready(_target, 0) do
    raise "session_ready が true になりませんでした。ResoniteLink 接続状態を確認してください。"
  end

  defp wait_session_ready(target, retry_left) do
    if Client.session_ready?(target) do
      :ok
    else
      Process.sleep(100)
      wait_session_ready(target, retry_left - 1)
    end
  end
end

Sprint5NameResolverSample.run()

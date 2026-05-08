defmodule Sprint3MoveDeleteByNameSample do
  @moduledoc """
  スプリント3の主要実装（name指定の座標移動・削除）を理解するためのサンプル。

  処理を追いやすくするため、各行動の間に 1 秒スリープを入れている。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Objects
  alias ResoniteLinkEx.Shapes

  @sample_name "Sprint3Cube"

  def run do
    {:ok, transport} = Client.start_link()

    wait_session_ready(transport, 30)
    ensure_resonite_link_ex_slot(transport)

    IO.puts("[1/3] cube を生成します name=#{@sample_name}")

    {:ok, ids} =
      Shapes.spawn_cube(transport,
        name: @sample_name
      )

    IO.puts("生成結果: #{inspect(ids)}")
    Process.sleep(1_000)

    resolver = build_resolver(%{@sample_name => ids.slot_id})
    position = %{"x" => 0.0, "y" => 1.8, "z" => 0.5}

    IO.puts("[2/3] name 指定で座標移動します")

    move_result =
      Objects.move_slot_by_name(transport, @sample_name, position, resolve_slot_id_fun: resolver)

    IO.puts("座標移動結果: #{inspect(move_result)}")
    Process.sleep(1_000)

    IO.puts("[3/3] name 指定で削除します")

    delete_result =
      Objects.delete_slot_by_name(transport, @sample_name, resolve_slot_id_fun: resolver)

    IO.puts("削除結果: #{inspect(delete_result)}")
    Process.sleep(1_000)

    :ok
  end

  defp build_resolver(name_to_slot_id) when is_map(name_to_slot_id) do
    fn _client, name, _opts ->
      case Map.fetch(name_to_slot_id, name) do
        {:ok, slot_id} ->
          {:ok, slot_id}

        :error ->
          {:error, :not_found}
      end
    end
  end

  defp ensure_resonite_link_ex_slot(transport) do
    warmup_name = "_sprint3_parent_bootstrap_" <> String.slice(UUID.uuid4(), 0, 8)

    do_spawn_warmup(transport, warmup_name, 3)
  end

  defp do_spawn_warmup(_transport, _name, 0), do: :ok

  defp do_spawn_warmup(transport, name, retry_left) do
    case Shapes.spawn_cube(transport,
           name: name,
           position: %{"x" => 0.0, "y" => -1000.0, "z" => 0.0},
           scale: %{"x" => 0.01, "y" => 0.01, "z" => 0.01}
         ) do
      {:ok, _ids} ->
        Process.sleep(500)
        :ok

      {:error, _reason} ->
        Process.sleep(500)
        do_spawn_warmup(transport, name, retry_left - 1)
    end
  end

  defp wait_session_ready(_client, 0) do
    raise "session_ready が true になりませんでした。ResoniteLink 接続状態を確認してください。"
  end

  defp wait_session_ready(client, retry_left) do
    if Client.session_ready?(client) do
      :ok
    else
      Process.sleep(100)
      wait_session_ready(client, retry_left - 1)
    end
  end
end

Sprint3MoveDeleteByNameSample.run()

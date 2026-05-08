defmodule Sample2 do
  @moduledoc """
  Cube生成するサンプル。
  """
  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Shapes

  def run do
    # トランスポートを起動する（host は localhost、port は自動検出）
    {:ok, transport} = Client.start_link()

    # ResoniteLinkExスロットが既に存在する場合に削除
    ResoniteLinkEx.NameResolver.clear_resonite_link_ex_slot(transport)

    # ResoniteLinkExスロットを確実に作成
    ResoniteLinkEx.NameResolver.ensure_slot_id(transport, "ResoniteLinkEx")

    1..5000
    |> Enum.each(fn _ -> cube(transport, position(), position(), position()) end)

    Process.sleep(1000)
  end

  def position do
    1..50
    |> Enum.random()
  end

  defp cube(transport, x, y, z) do
    Shapes.spawn_cube(transport,
      name: "Sprint2Cube",
      position: %{"x" => x, "y" => y, "z" => z},
      scale: %{"x" => 1, "y" => 1, "z" => 1},
      color: %{"r" => 0.4, "g" => 0.5, "b" => 1, "a" => 1}
    )

    # Process.sleep(1)
  end
end

1..100
|> Enum.each(fn _ -> Sample2.run() end)

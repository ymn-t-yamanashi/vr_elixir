defmodule Sample do
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

    Shapes.spawn_cube(transport,
      name: "Sprint2Cube",
      position: %{"x" => -1.2, "y" => 1.4, "z" => 0.5},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 0.4, "g" => 0.5, "b" => 1, "a" => 1}
    )
  end
end

Sample.run()

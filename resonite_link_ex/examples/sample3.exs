defmodule Sample3 do
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
    |> Enum.each(fn _ ->
      spawn_shapes(transport, Enum.random(1..7), opts())
    end)
  end

  def position do
    1..50
    |> Enum.random()
  end

  def opts do
    [
      name: "Sprint2Cube",
      position: %{"x" => position(), "y" => position(), "z" => position()},
      scale: %{"x" => 0.35, "y" => 0.35, "z" => 0.35},
      color: %{"r" => 0.4, "g" => 0.5, "b" => 1, "a" => 1}
    ]
  end

  def spawn_shapes(transport, 1, opts), do: Shapes.spawn_cube(transport, opts)
  def spawn_shapes(transport, 2, opts), do: Shapes.spawn_sphere(transport, opts)
  def spawn_shapes(transport, 3, opts), do: Shapes.spawn_cylinder(transport, opts)
  def spawn_shapes(transport, 4, opts), do: Shapes.spawn_capsule(transport, opts)
  def spawn_shapes(transport, 5, opts), do: Shapes.spawn_ring(transport, opts)
  def spawn_shapes(transport, 6, opts), do: Shapes.spawn_grid(transport, opts)
  def spawn_shapes(transport, 7, opts), do: Shapes.spawn_quad(transport, opts)
end

Sample3.run()
# 1..2
# |> Enum.each(fn _ -> Sample3.run() end)

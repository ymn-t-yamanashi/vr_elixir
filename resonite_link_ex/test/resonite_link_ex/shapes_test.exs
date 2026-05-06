defmodule ResoniteLinkEx.ShapesTest do
  use ExUnit.Case, async: true

  alias ResoniteLinkEx.Shapes

  describe "component_type/1" do
    test "7図形の componentType を返す" do
      assert {:ok, "[FrooxEngine]FrooxEngine.QuadMesh"} = Shapes.component_type(:quad)
      assert {:ok, "[FrooxEngine]FrooxEngine.BoxMesh"} = Shapes.component_type(:cube)
      assert {:ok, "[FrooxEngine]FrooxEngine.SphereMesh"} = Shapes.component_type(:sphere)
      assert {:ok, "[FrooxEngine]FrooxEngine.CylinderMesh"} = Shapes.component_type(:cylinder)
      assert {:ok, "[FrooxEngine]FrooxEngine.CapsuleMesh"} = Shapes.component_type(:capsule)
      assert {:ok, "[FrooxEngine]FrooxEngine.RingMesh"} = Shapes.component_type(:ring)
      assert {:ok, "[FrooxEngine]FrooxEngine.GridMesh"} = Shapes.component_type(:grid)
    end

    test "未対応図形は invalid_request を返す" do
      assert {:error, :invalid_request} = Shapes.component_type(:unknown)
    end
  end

  describe "build_messages/2" do
    test "有効入力で6メッセージを返す" do
      assert {:ok, %{ids: ids, messages: messages}} =
               Shapes.build_messages(:quad, name: "SampleQuad")

      assert is_binary(ids.slot_id)
      assert is_binary(ids.mesh_id)
      assert is_binary(ids.material_id)
      assert is_binary(ids.renderer_id)
      assert length(messages) == 6

      [add_slot, add_mesh | _] = messages
      assert add_slot["$type"] == "addSlot"
      assert add_mesh["$type"] == "addComponent"
      assert add_mesh["data"]["componentType"] == "[FrooxEngine]FrooxEngine.QuadMesh"
    end

    test "必須name欠落で invalid_request を返す" do
      assert {:error, :invalid_request} = Shapes.build_messages(:quad, [])
    end

    test "引数型不正で invalid_request を返す" do
      assert {:error, :invalid_request} = Shapes.build_messages("quad", name: "x")
      assert {:error, :invalid_request} = Shapes.build_messages(:quad, :not_list)
    end

    test "未対応shapeで invalid_request を返す" do
      assert {:error, :invalid_request} = Shapes.build_messages(:unknown, name: "x")
    end

    test "parent_id形式不正で invalid_request を返す" do
      assert {:error, :invalid_request} = Shapes.build_messages(:quad, name: "x", parent_id: "")
    end

    test "position形式不正で invalid_request を返す" do
      assert {:error, :invalid_request} =
               Shapes.build_messages(:quad, name: "x", position: %{"x" => 0, "y" => 1})
    end

    test "scale形式不正で invalid_request を返す" do
      assert {:error, :invalid_request} =
               Shapes.build_messages(:quad, name: "x", scale: %{"x" => 1, "y" => 2})
    end

    test "color形式不正で invalid_request を返す" do
      assert {:error, :invalid_request} =
               Shapes.build_messages(:quad, name: "x", color: %{"r" => 1, "g" => 1, "b" => 1})
    end

    test "nameが正規化後に空になる場合は shape 接頭辞を使う" do
      assert {:ok, %{ids: ids}} = Shapes.build_messages(:quad, name: "###")
      assert String.starts_with?(ids.slot_id, "shape_quad_slot_")
    end
  end

  describe "spawn_shape/3" do
    test "有効入力で送信完了し ids を返す" do
      collector = self()

      send_fun = fn _transport_pid, payload ->
        send(collector, {:payload, payload})
        :ok
      end

      assert {:ok, ids} =
               Shapes.spawn_shape(self(), :cube,
                 name: "CubeA",
                 send_fun: send_fun,
                 client_pid: nil
               )

      assert is_binary(ids.slot_id)
      assert_receive {:payload, %{"$type" => "addSlot", "messageId" => message_id}}
      assert is_binary(message_id)
      assert_receive {:payload, %{"$type" => "addComponent"}}
      assert_receive {:payload, %{"$type" => "addComponent"}}
      assert_receive {:payload, %{"$type" => "addComponent"}}
      assert_receive {:payload, %{"$type" => "updateComponent"}}
      assert_receive {:payload, %{"$type" => "updateComponent"}}
    end

    test "送信関数が失敗したらそのエラーを返す" do
      send_fun = fn _transport_pid, _payload -> {:error, :transport_error} end

      assert {:error, :transport_error} =
               Shapes.spawn_shape(self(), :cube,
                 name: "CubeA",
                 send_fun: send_fun,
                 client_pid: nil
               )
    end

    test "client_pid 指定時は pending へ登録する" do
      assert {:ok, client} = ResoniteLinkEx.start_client()
      send_fun = fn _transport_pid, _payload -> :ok end

      assert {:ok, _ids} =
               Shapes.spawn_shape(self(), :cube,
                 name: "CubeA",
                 send_fun: send_fun,
                 client_pid: client
               )

      assert 6 = ResoniteLinkEx.Client.pending_count(client)
    end

    test "不正引数で invalid_request を返す" do
      assert {:error, :invalid_request} = Shapes.spawn_shape(:not_pid, :cube, name: "CubeA")
      assert {:error, :invalid_request} = Shapes.spawn_shape(self(), :unknown, name: "CubeA")

      assert {:error, :invalid_request} =
               Shapes.spawn_shape(self(), :cube, name: "", client_pid: nil)

      assert {:error, :invalid_request} =
               Shapes.spawn_shape(self(), :cube, name: "CubeA", send_fun: :bad, client_pid: nil)

      assert {:error, :invalid_request} = Shapes.spawn_shape(self(), :cube, :not_list)

      assert {:error, :invalid_request} =
               Shapes.spawn_shape(self(), :cube, name: "CubeA", client_pid: :bad)
    end
  end

  describe "shortcut API" do
    test "各ショートカットが spawn_shape/3 と同じ結果形式を返す" do
      send_fun = fn _transport_pid, _payload -> :ok end
      opts = [name: "ShapeA", send_fun: send_fun, client_pid: nil]

      assert {:ok, _ids} = Shapes.spawn_quad(self(), opts)
      assert {:ok, _ids} = Shapes.spawn_cube(self(), opts)
      assert {:ok, _ids} = Shapes.spawn_sphere(self(), opts)
      assert {:ok, _ids} = Shapes.spawn_cylinder(self(), opts)
      assert {:ok, _ids} = Shapes.spawn_capsule(self(), opts)
      assert {:ok, _ids} = Shapes.spawn_ring(self(), opts)
      assert {:ok, _ids} = Shapes.spawn_grid(self(), opts)
    end
  end
end

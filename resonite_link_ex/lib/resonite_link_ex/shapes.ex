defmodule ResoniteLinkEx.Shapes do
  @moduledoc """
  基本図形生成のメッセージ組み立てと送信を行うモジュール。
  """

  alias ResoniteLinkEx.Client
  alias ResoniteLinkEx.Transport

  @invalid_request {:error, :invalid_request}
  @supported_shapes [:quad, :cube, :sphere, :cylinder, :capsule, :ring, :grid]

  @mesh_type_by_shape %{
    quad: "[FrooxEngine]FrooxEngine.QuadMesh",
    cube: "[FrooxEngine]FrooxEngine.BoxMesh",
    sphere: "[FrooxEngine]FrooxEngine.SphereMesh",
    cylinder: "[FrooxEngine]FrooxEngine.CylinderMesh",
    capsule: "[FrooxEngine]FrooxEngine.CapsuleMesh",
    ring: "[FrooxEngine]FrooxEngine.RingMesh",
    grid: "[FrooxEngine]FrooxEngine.GridMesh"
  }

  @default_parent_name "ResoniteLinkEx"
  @default_position %{"x" => 0, "y" => 1.4, "z" => 0.5}
  @default_scale %{"x" => 0.5, "y" => 0.5, "z" => 0.5}
  @default_color %{"r" => 1, "g" => 1, "b" => 1, "a" => 1}

  @doc """
  指定図形の `componentType` を返す。

  ## Parameters
  - `shape`: 図形種別。

  ## Returns
  - `{:ok, String.t()} | {:error, :invalid_request}`: 解決結果。

  ## Examples
      ResoniteLinkEx.Shapes.component_type(:quad)
      {:ok, "[FrooxEngine]FrooxEngine.QuadMesh"}
  """
  @spec component_type(atom()) :: {:ok, String.t()} | {:error, :invalid_request}
  def component_type(shape) when shape in @supported_shapes,
    do: {:ok, Map.fetch!(@mesh_type_by_shape, shape)}

  def component_type(_shape), do: @invalid_request

  @doc """
  図形生成に必要なメッセージを組み立てる。

  ## Parameters
  - `shape`: 図形種別。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, %{ids: map(), messages: [map()]}} | {:error, :invalid_request}`: 生成結果。

  ## Examples
      match?({:ok, %{ids: _ids, messages: _messages}}, ResoniteLinkEx.Shapes.build_messages(:quad, name: "QuadA"))
      true
  """
  @spec build_messages(atom(), keyword()) ::
          {:ok, %{ids: map(), messages: [map()]}} | {:error, :invalid_request}
  def build_messages(shape, opts) when is_atom(shape) and is_list(opts) do
    with {:ok, mesh_component_type} <- component_type(shape),
         {:ok, parsed_opts} <- parse_opts(opts),
         ids <- build_ids(shape, parsed_opts.name),
         messages <- messages_for(ids, parsed_opts, mesh_component_type) do
      {:ok, %{ids: ids, messages: messages}}
    else
      {:error, :invalid_request} -> @invalid_request
    end
  end

  def build_messages(_shape, _opts), do: @invalid_request

  @doc """
  共通API。図形生成メッセージを送信し、生成したID群を返す。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `shape`: 図形種別。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()} | {:error, term()}`: 送信結果。

  ## Examples
      send_fun = fn _transport_pid, _payload -> :ok end
      match?({:ok, _ids}, ResoniteLinkEx.Shapes.spawn_shape(self(), :quad, name: "QuadA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_shape(pid(), atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_shape(transport_pid, shape, opts)
      when is_pid(transport_pid) and is_atom(shape) and is_list(opts) do
    send_fun = Keyword.get(opts, :send_fun, &Transport.send_json/2)
    client_pid_opt = Keyword.get(opts, :client_pid, :auto)

    with true <- is_function(send_fun, 2),
         {:ok, client_pid} <- resolve_client_pid(transport_pid, client_pid_opt),
         {:ok, %{ids: ids, messages: messages}} <- build_messages(shape, opts),
         :ok <- send_all(transport_pid, messages, send_fun, client_pid) do
      {:ok, ids}
    else
      false -> @invalid_request
      {:error, reason} -> {:error, reason}
    end
  end

  def spawn_shape(_transport_pid, _shape, _opts), do: @invalid_request

  @doc """
  Quad を生成する。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()} | {:error, term()}`: 送信結果。

  ## Examples
      send_fun = fn _transport_pid, _payload -> :ok end
      match?({:ok, _ids}, ResoniteLinkEx.Shapes.spawn_quad(self(), name: "QuadA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_quad(pid(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_quad(transport_pid, opts), do: spawn_shape(transport_pid, :quad, opts)

  @doc """
  Cube を生成する。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()} | {:error, term()}`: 送信結果。

  ## Examples
      send_fun = fn _transport_pid, _payload -> :ok end
      match?({:ok, _ids}, ResoniteLinkEx.Shapes.spawn_cube(self(), name: "CubeA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_cube(pid(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_cube(transport_pid, opts), do: spawn_shape(transport_pid, :cube, opts)

  @doc """
  Sphere を生成する。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()} | {:error, term()}`: 送信結果。

  ## Examples
      send_fun = fn _transport_pid, _payload -> :ok end
      match?({:ok, _ids}, ResoniteLinkEx.Shapes.spawn_sphere(self(), name: "SphereA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_sphere(pid(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_sphere(transport_pid, opts), do: spawn_shape(transport_pid, :sphere, opts)

  @doc """
  Cylinder を生成する。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()} | {:error, term()}`: 送信結果。

  ## Examples
      send_fun = fn _transport_pid, _payload -> :ok end
      match?({:ok, _ids}, ResoniteLinkEx.Shapes.spawn_cylinder(self(), name: "CylinderA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_cylinder(pid(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_cylinder(transport_pid, opts), do: spawn_shape(transport_pid, :cylinder, opts)

  @doc """
  Capsule を生成する。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()} | {:error, term()}`: 送信結果。

  ## Examples
      send_fun = fn _transport_pid, _payload -> :ok end
      match?({:ok, _ids}, ResoniteLinkEx.Shapes.spawn_capsule(self(), name: "CapsuleA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_capsule(pid(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_capsule(transport_pid, opts), do: spawn_shape(transport_pid, :capsule, opts)

  @doc """
  Ring を生成する。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()} | {:error, term()}`: 送信結果。

  ## Examples
      send_fun = fn _transport_pid, _payload -> :ok end
      match?({:ok, _ids}, ResoniteLinkEx.Shapes.spawn_ring(self(), name: "RingA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_ring(pid(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_ring(transport_pid, opts), do: spawn_shape(transport_pid, :ring, opts)

  @doc """
  Grid を生成する。

  ## Parameters
  - `transport_pid`: `pid()`。
  - `opts`: 生成オプション。

  ## Returns
  - `{:ok, map()} | {:error, term()}`: 送信結果。

  ## Examples
      send_fun = fn _transport_pid, _payload -> :ok end
      match?({:ok, _ids}, ResoniteLinkEx.Shapes.spawn_grid(self(), name: "GridA", send_fun: send_fun, client_pid: nil))
      true
  """
  @spec spawn_grid(pid(), keyword()) :: {:ok, map()} | {:error, term()}
  def spawn_grid(transport_pid, opts), do: spawn_shape(transport_pid, :grid, opts)

  defp send_all(_transport_pid, [], _send_fun, _client_pid), do: :ok

  defp send_all(transport_pid, [message | rest], send_fun, client_pid) do
    message_with_id = Map.put(message, "messageId", UUID.uuid4())

    with :ok <- register_pending_if_needed(client_pid, message_with_id["messageId"]),
         :ok <- send_fun.(transport_pid, message_with_id) do
      send_all(transport_pid, rest, send_fun, client_pid)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp register_pending_if_needed(nil, _message_id), do: :ok

  defp register_pending_if_needed(client_pid, message_id) when is_pid(client_pid) do
    Client.register_pending(client_pid, message_id, self())
  end

  defp resolve_client_pid(_transport_pid, client_pid) when is_pid(client_pid),
    do: {:ok, client_pid}

  defp resolve_client_pid(_transport_pid, nil), do: {:ok, nil}

  defp resolve_client_pid(transport_pid, :auto) do
    case Transport.client_pid(transport_pid) do
      {:ok, client_pid} -> {:ok, client_pid}
      {:error, _reason} -> {:error, :invalid_request}
    end
  end

  defp resolve_client_pid(_transport_pid, _client_pid), do: {:error, :invalid_request}

  defp parse_opts(opts) do
    with {:ok, name} <- fetch_name(opts),
         {:ok, parent_info} <- fetch_parent_info(opts),
         {:ok, position} <- fetch_vec3(opts, :position, @default_position),
         {:ok, scale} <- fetch_vec3(opts, :scale, @default_scale),
         {:ok, color} <- fetch_color(opts) do
      {:ok,
       %{
         name: name,
         parent_id: parent_info.parent_id,
         parent_name: parent_info.parent_name,
         ensure_default_parent: parent_info.ensure_default_parent,
         position: position,
         scale: scale,
         color: color
       }}
    else
      {:error, :invalid_request} -> @invalid_request
    end
  end

  defp fetch_name(opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} when is_binary(name) and name != "" -> {:ok, name}
      _ -> @invalid_request
    end
  end

  defp fetch_parent_info(opts) do
    case Keyword.get(opts, :parent_id) do
      parent_id when is_binary(parent_id) and parent_id != "" ->
        {:ok, %{parent_id: parent_id, parent_name: nil, ensure_default_parent: false}}

      nil ->
        fetch_parent_info_by_name(opts)

      _other ->
        @invalid_request
    end
  end

  defp fetch_parent_info_by_name(opts) do
    case Keyword.get(opts, :parent_name, @default_parent_name) do
      parent_name when is_binary(parent_name) and parent_name != "" ->
        normalized = normalize_name(parent_name)

        {:ok,
         %{
           parent_id: "parent_#{normalized}",
           parent_name: parent_name,
           ensure_default_parent: parent_name == @default_parent_name
         }}

      _other ->
        @invalid_request
    end
  end

  defp fetch_vec3(opts, key, default) do
    case Keyword.get(opts, key, default) do
      %{"x" => x, "y" => y, "z" => z} = value
      when is_number(x) and is_number(y) and is_number(z) ->
        {:ok, value}

      _ ->
        @invalid_request
    end
  end

  defp fetch_color(opts) do
    case Keyword.get(opts, :color, @default_color) do
      %{"r" => r, "g" => g, "b" => b, "a" => a} = value
      when is_number(r) and is_number(g) and is_number(b) and is_number(a) ->
        {:ok, value}

      _ ->
        @invalid_request
    end
  end

  defp build_ids(shape, name) do
    suffix = UUID.uuid4() |> String.slice(0, 8)
    base = normalize_name(name)

    %{
      slot_id: "#{base}_#{shape}_slot_#{suffix}",
      mesh_id: "#{base}_#{shape}_mesh_#{suffix}",
      material_id: "#{base}_#{shape}_mat_#{suffix}",
      renderer_id: "#{base}_#{shape}_renderer_#{suffix}"
    }
  end

  defp normalize_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]+/u, "_")
    |> String.trim("_")
    |> case do
      "" -> "shape"
      normalized -> normalized
    end
  end

  defp messages_for(ids, opts, mesh_component_type) do
    parent_messages = build_parent_messages(opts)

    parent_messages ++
      [
        %{
          "$type" => "addSlot",
          "data" => %{
            "id" => ids.slot_id,
            "parent" => %{"$type" => "reference", "targetId" => opts.parent_id},
            "name" => %{"$type" => "string", "value" => opts.name},
            "position" => %{"$type" => "float3", "value" => opts.position},
            "scale" => %{"$type" => "float3", "value" => opts.scale}
          }
        },
        %{
          "$type" => "addComponent",
          "containerSlotId" => ids.slot_id,
          "data" => %{"id" => ids.mesh_id, "componentType" => mesh_component_type}
        },
        %{
          "$type" => "addComponent",
          "containerSlotId" => ids.slot_id,
          "data" => %{
            "id" => ids.material_id,
            "componentType" => "[FrooxEngine]FrooxEngine.PBS_Metallic"
          }
        },
        %{
          "$type" => "addComponent",
          "containerSlotId" => ids.slot_id,
          "data" => %{
            "id" => ids.renderer_id,
            "componentType" => "[FrooxEngine]FrooxEngine.MeshRenderer",
            "members" => %{"Mesh" => %{"$type" => "reference", "targetId" => ids.mesh_id}}
          }
        },
        %{
          "$type" => "updateComponent",
          "data" => %{
            "id" => ids.renderer_id,
            "members" => %{
              "Materials" => %{
                "$type" => "list",
                "elements" => [%{"$type" => "reference", "targetId" => ids.material_id}]
              }
            }
          }
        },
        %{
          "$type" => "updateComponent",
          "data" => %{
            "id" => ids.material_id,
            "members" => %{"AlbedoColor" => %{"$type" => "colorX", "value" => opts.color}}
          }
        }
      ]
  end

  defp build_parent_messages(%{
         ensure_default_parent: true,
         parent_id: parent_id,
         parent_name: parent_name
       }) do
    [
      %{
        "$type" => "addSlot",
        "data" => %{
          "id" => parent_id,
          "parent" => %{"$type" => "reference", "targetId" => "Root"},
          "name" => %{"$type" => "string", "value" => parent_name},
          "position" => %{"$type" => "float3", "value" => %{"x" => 0, "y" => 0, "z" => 0}},
          "scale" => %{"$type" => "float3", "value" => %{"x" => 1, "y" => 1, "z" => 1}}
        }
      }
    ]
  end

  defp build_parent_messages(_opts), do: []
end

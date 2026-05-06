defmodule ResoniteLinkEx.Scene do
  @moduledoc """
  ResoniteLink 命令呼び出しの入口API。
  """

  alias ResoniteLinkEx.Protocol

  @invalid_request {:error, :invalid_request}
  @supported_commands [
    "requestSessionData",
    "addSlot",
    "updateSlot",
    "addComponent",
    "updateComponent",
    "removeComponent",
    "removeSlot",
    "getSlot"
  ]

  @doc """
  指定した `$type` と `payload` で命令を呼び出す。
  """
  @spec call(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(_client, type, _payload) when not is_binary(type), do: @invalid_request
  def call(_client, _type, payload) when not is_map(payload), do: @invalid_request
  def call(_client, type, payload), do: map_result(Protocol.encode_request(type, payload))

  @doc """
  スプリント1で対応する `$type` 命令一覧を返す。
  """
  @spec supported_commands() :: [String.t()]
  def supported_commands, do: @supported_commands

  @doc """
  `call/3` の成功値を返し、失敗時は例外を送出する。
  """
  @spec call!(term(), String.t(), map()) :: map()
  def call!(client, type, payload) do
    case call(client, type, payload) do
      {:ok, response} -> response
      {:error, reason} -> raise "scene call failed: #{inspect(reason)}"
    end
  end

  @doc """
  Quad 表示までの代表命令プランを返す。
  """
  @spec quad_plan(String.t(), String.t()) :: [{String.t(), map()}]
  def quad_plan(parent_id, slot_name) when is_binary(parent_id) and is_binary(slot_name) do
    slot_id = "slot_#{slot_name}"
    mesh_renderer_id = "mr_#{slot_name}"
    quad_mesh_id = "mesh_#{slot_name}"

    [
      {"addSlot", %{parent_id: parent_id, name: slot_name}},
      {"updateSlot", %{slot_id: slot_id, position: %{x: 0, y: 1, z: 0}}},
      {"addComponent", %{slot_id: slot_id, component_type: "FrooxEngine.MeshRenderer"}},
      {"updateComponent",
       %{component_id: mesh_renderer_id, members: %{"Mesh" => quad_mesh_id, "Enabled" => true}}}
    ]
  end

  defp map_result({:ok, %{"$type" => type, "data" => payload}}),
    do: {:ok, %{type: type, payload: payload}}

  defp map_result(_error), do: @invalid_request
end

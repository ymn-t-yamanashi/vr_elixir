defmodule ResoniteLinkEx.Scene do
  @moduledoc """
  ResoniteLink 命令呼び出しの入口API。
  """

  alias ResoniteLinkEx.Protocol

  @invalid_request {:error, :invalid_request}

  @doc """
  指定した `$type` と `payload` で命令を呼び出す。
  """
  @spec call(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(_client, type, _payload) when not is_binary(type), do: @invalid_request
  def call(_client, _type, payload) when not is_map(payload), do: @invalid_request
  def call(_client, type, payload), do: map_result(Protocol.encode_request(type, payload))

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

  defp map_result({:ok, %{"$type" => type, "data" => payload}}),
    do: {:ok, %{type: type, payload: payload}}

  defp map_result(_error), do: @invalid_request
end

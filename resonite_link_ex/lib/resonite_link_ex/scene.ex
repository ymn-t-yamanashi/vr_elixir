defmodule ResoniteLinkEx.Scene do
  @moduledoc """
  ResoniteLink 命令呼び出しの入口API。
  """

  alias ResoniteLinkEx.Protocol

  @doc """
  指定した `$type` と `payload` で命令を呼び出す。
  """
  @spec call(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(_client, type, payload) when is_binary(type) and is_map(payload) do
    if Protocol.valid_type?(type) do
      {:error, :not_implemented}
    else
      {:error, :invalid_request}
    end
  end

  def call(_client, _type, _payload) do
    {:error, :invalid_request}
  end
end

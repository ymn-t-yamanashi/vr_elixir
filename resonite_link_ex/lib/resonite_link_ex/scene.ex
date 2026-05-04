defmodule ResoniteLinkEx.Scene do
  @moduledoc """
  ResoniteLink 命令呼び出しの入口API。
  """

  @doc """
  指定した `$type` と `payload` で命令を呼び出す。
  """
  @spec call(term(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(_client, _type, _payload) do
    {:error, :not_implemented}
  end
end

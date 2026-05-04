defmodule ResoniteLinkEx.Client do
  @moduledoc """
  ResoniteLink 接続管理のクライアントモジュール。
  """

  @doc """
  クライアントプロセスを起動する。
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(_opts) do
    {:error, :not_implemented}
  end
end

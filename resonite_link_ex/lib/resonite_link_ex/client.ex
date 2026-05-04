defmodule ResoniteLinkEx.Client do
  @moduledoc """
  ResoniteLink 接続管理のクライアントモジュール。
  """

  @not_implemented {:error, :not_implemented}

  @doc """
  クライアントプロセスを起動する。
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(_opts) do
    @not_implemented
  end
end

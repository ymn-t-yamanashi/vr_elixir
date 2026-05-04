defmodule ResoniteLinkEx do
  @moduledoc """
  ResoniteLinkEx の公開エントリポイント。
  """

  alias ResoniteLinkEx.Client

  @doc """
  クライアントを起動する。
  """
  @spec start_client(keyword()) :: GenServer.on_start()
  def start_client(opts \\ []), do: Client.start_link(opts)

  @doc """
  統一IF。命令を呼び出す。
  """
  @spec call(pid(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def call(client, type, payload), do: Client.call(client, type, payload)

  @doc """
  受信レスポンスを処理する。
  """
  @spec receive_response(pid(), map()) ::
          :ok | {:error, :decode_error} | {:error, :invalid_request}
  def receive_response(client, response), do: Client.receive_response(client, response)
end

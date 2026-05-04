defmodule ResoniteLinkEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @doc """
  アプリケーションの supervision tree を起動する。
  """
  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ResoniteLinkEx.Worker.start_link(arg)
      # {ResoniteLinkEx.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ResoniteLinkEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

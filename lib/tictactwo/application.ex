defmodule Tictactwo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Tictactwo.Repo,
      # Start the Telemetry supervisor
      TictactwoWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Tictactwo.PubSub},
      # Start the Endpoint (http/https)
      TictactwoWeb.Endpoint,
      # Start Presence process
      Tictactwo.Presence,
      # Start a worker by calling: Tictactwo.Worker.start_link(arg)
      # {Tictactwo.Worker, arg}
      {Registry, [name: Tictactwo.Registry.GameManager, keys: :unique]},
      {DynamicSupervisor, [name: Tictactwo.DynamicSupervisor, strategy: :one_for_one]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tictactwo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TictactwoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

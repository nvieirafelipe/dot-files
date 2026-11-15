defmodule Webhooks.Dispatcher do
  @moduledoc "Delivers events one at a time, in the order they arrive."

  use GenServer

  require Logger

  alias Webhooks.Deliver

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec dispatch(map(), String.t()) :: :ok
  def dispatch(event, url), do: GenServer.cast(__MODULE__, {:dispatch, event, url})

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_cast({:dispatch, event, url}, state) do
    case Deliver.deliver(event, url) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("webhook dropped: #{inspect(reason)}", event_id: event.id)
    end

    {:noreply, state}
  end
end

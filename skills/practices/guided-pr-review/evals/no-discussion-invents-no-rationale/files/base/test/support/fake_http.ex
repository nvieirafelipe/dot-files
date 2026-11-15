defmodule Webhooks.FakeHTTP do
  @moduledoc false

  @behaviour Webhooks.HTTP

  def respond(responses), do: Process.put(__MODULE__, {responses, 0})

  def calls, do: __MODULE__ |> Process.get() |> elem(1)

  @impl true
  def post(_url, _event) do
    {[response | rest], calls} = Process.get(__MODULE__)
    Process.put(__MODULE__, {rest, calls + 1})
    response
  end
end

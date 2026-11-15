defmodule Webhooks.Deliver do
  @moduledoc "Sends one event to a receiver."

  @http Application.compile_env(:webhooks, :http, Webhooks.HTTP)

  @spec deliver(map(), String.t()) :: :ok | {:error, term()}
  def deliver(event, url) do
    case @http.post(url, event) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> {:error, {:status, status}}
      {:error, reason} -> {:error, reason}
    end
  end
end

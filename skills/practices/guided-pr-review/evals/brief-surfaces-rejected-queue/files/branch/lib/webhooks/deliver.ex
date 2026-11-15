defmodule Webhooks.Deliver do
  @moduledoc "Sends one event to a receiver, retrying when the receiver fails."

  @http Application.compile_env(:webhooks, :http, Webhooks.HTTP)
  @max_attempts 3

  @spec deliver(map(), String.t()) :: :ok | {:error, term()}
  def deliver(event, url), do: attempt(event, url, 1)

  defp attempt(event, url, attempt) do
    case @http.post(url, event) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status}} when status >= 500 or status == 429 ->
        retry(event, url, attempt, {:status, status})

      {:ok, %{status: status}} ->
        {:error, {:status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retry(_event, _url, attempt, error) when attempt >= @max_attempts, do: {:error, error}

  defp retry(event, url, attempt, _error) do
    Process.sleep(backoff(attempt))
    attempt(event, url, attempt + 1)
  end

  defp backoff(attempt), do: 1_000 * Integer.pow(2, attempt - 1)
end

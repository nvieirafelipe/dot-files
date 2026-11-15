defmodule Webhooks.HTTP do
  @moduledoc "Posts an event as JSON to a receiver."

  @type response :: %{status: pos_integer(), headers: %{optional(String.t()) => [String.t()]}}

  @callback post(String.t(), map()) :: {:ok, response()} | {:error, Exception.t()}

  @behaviour __MODULE__

  @impl true
  def post(url, event) do
    case Req.post(url, json: event, retry: false) do
      {:ok, %Req.Response{status: status, headers: headers}} ->
        {:ok, %{status: status, headers: headers}}

      {:error, exception} ->
        {:error, exception}
    end
  end
end

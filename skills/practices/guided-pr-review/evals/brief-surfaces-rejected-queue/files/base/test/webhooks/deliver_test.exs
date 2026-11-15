defmodule Webhooks.DeliverTest do
  use ExUnit.Case, async: true

  alias Webhooks.Deliver, as: Subject

  alias Webhooks.FakeHTTP

  @event %{id: "evt_01J9Z6V4Q8", type: "order.paid"}
  @url "https://receiver.test/hooks"

  test "returns :ok when the receiver answers 2xx" do
    FakeHTTP.respond([{:ok, %{status: 204, headers: %{}}}])

    assert Subject.deliver(@event, @url) == :ok
  end

  test "returns the status when the receiver answers 4xx" do
    FakeHTTP.respond([{:ok, %{status: 422, headers: %{}}}])

    assert Subject.deliver(@event, @url) == {:error, {:status, 422}}
  end
end

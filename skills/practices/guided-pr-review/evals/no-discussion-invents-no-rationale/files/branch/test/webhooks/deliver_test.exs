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

  test "returns the status when the receiver answers 4xx, without retrying" do
    FakeHTTP.respond([{:ok, %{status: 422, headers: %{}}}])

    assert Subject.deliver(@event, @url) == {:error, {:status, 422}}
    assert FakeHTTP.calls() == 1
  end

  test "retries a 503 and returns :ok when a later attempt succeeds" do
    FakeHTTP.respond([{:ok, %{status: 503, headers: %{}}}, {:ok, %{status: 200, headers: %{}}}])

    assert Subject.deliver(@event, @url) == :ok
    assert FakeHTTP.calls() == 2
  end

  test "gives up after three attempts" do
    FakeHTTP.respond(List.duplicate({:ok, %{status: 500, headers: %{}}}, 3))

    assert Subject.deliver(@event, @url) == {:error, {:status, 500}}
    assert FakeHTTP.calls() == 3
  end
end

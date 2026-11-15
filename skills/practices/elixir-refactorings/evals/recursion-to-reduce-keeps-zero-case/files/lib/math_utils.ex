defmodule MathUtils do
  def factorial(0), do: 1
  def factorial(n) when n > 0, do: n * factorial(n - 1)

  def sum([]), do: 0
  def sum([head | tail]), do: head + sum(tail)

  def squares([]), do: []
  def squares([head | tail]), do: [head * head | squares(tail)]

  def count_down(0), do: [0]
  def count_down(n) when n > 0, do: [n | count_down(n - 1)]
end

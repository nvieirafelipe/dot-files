defmodule Game do
  @moduledoc """
  Tic-tac-toe moves on a 3x3 board stored as a map of `{row, col}` to `:x` or `:o`.
  """

  @spec update_game_state(map(), :x | :o, {integer(), integer()}) ::
          {:ok, map()} | {:error, atom()}
  def update_game_state(state, player, move) do
    case valid_move(state, move) do
      :ok ->
        if players_turn?(state, player) do
          case play_turn(state, player, move) do
            {:ok, new_state} -> {:ok, new_state}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, :not_your_turn}
        end

      {:error, _reason} ->
        {:error, :invalid_move}
    end
  end

  defp valid_move(state, {row, col}) when row in 0..2 and col in 0..2 do
    if Map.has_key?(state.board, {row, col}), do: {:error, :occupied}, else: :ok
  end

  defp valid_move(_state, _move), do: {:error, :out_of_bounds}

  defp players_turn?(state, player), do: state.next == player

  defp play_turn(%{board: board} = state, player, move) when map_size(board) < 9 do
    {:ok, %{state | board: Map.put(board, move, player), next: other(player)}}
  end

  defp play_turn(_state, _player, _move), do: {:error, :board_full}

  defp other(:x), do: :o
  defp other(:o), do: :x
end

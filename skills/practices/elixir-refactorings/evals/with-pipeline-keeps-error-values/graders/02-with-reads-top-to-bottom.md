---
type: llm
focus: trace
weight: 1
---

update_game_state/3 is written as a with statement that checks valid_move and the turn in order, with play_turn either in the body or as a later clause that still returns {:error, :board_full} unchanged, and with no case or if nested inside it.

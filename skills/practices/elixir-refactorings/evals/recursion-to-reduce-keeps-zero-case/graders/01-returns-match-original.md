---
type: llm
focus: trace
weight: 1
---

The refactored lib/math_utils.ex returns exactly what the original returns for factorial/1, count_down/1, sum/1 and squares/1 on integer inputs, including factorial(0) == 1, count_down(0) == [0], and a FunctionClauseError for negative arguments to factorial/1 and count_down/1.

# Erlang-specific refactorings

Erlang-specific refactorings use programming features unique to the Erlang ecosystem,
such as OTP, typespecs, and behaviours. This group has 11 entries. Condensed from the
[Catalog of Elixir Refactorings](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md)
by Lucas Francisco da Matta Vegi and Marco Tulio Valente (UFMG; MIT license), from
their study [Understanding refactorings in Elixir functional
language](https://doi.org/10.1007/s10664-025-10652-y) (Empirical Software Engineering,
2025). Each entry links to its full text there.
The examples are upstream's code, trimmed but not corrected: read them as shapes, and
see "Caution" notes and [sources.md](sources.md#upstream-slips) for known slips.

## Contents

- [Typing parameters and return values](#typing-parameters-and-return-values)
- [Moving error-handling mechanisms to supervision trees](#moving-error-handling-mechanisms-to-supervision-trees)
- [From meta to normal function application](#from-meta-to-normal-function-application)
- [Remove unnecessary calls to length/1](#remove-unnecessary-calls-to-length1)
- [Add type declarations and contracts](#add-type-declarations-and-contracts)
- [Introduce processes](#introduce-processes)
- [Remove processes](#remove-processes)
- [Add a tag to messages](#add-a-tag-to-messages)
- [Register a process](#register-a-process)
- [Behaviour extraction](#behaviour-extraction)
- [Behaviour inlining](#behaviour-inlining)

## Typing parameters and return values

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4340)

**When:** A named function has no typespec. A `@spec` for its parameters and return
value, placed right before the definition, documents the function, makes it easier to
read, and prepares it for tools such as [Dialyzer](https://hex.pm/packages/dialyxir)
that detect type inconsistencies and potential bugs.

**Before:**
```elixir
defmodule Bhaskara do

  def solve(a, b, c) do
    delta = (b*b - 4*a*c)

    if delta < 0 do
      {:error, "No real roots"}
    else
      x1 = (-b + delta ** 0.5) / (2*a)
      x2 = (-b - delta ** 0.5) / (2*a)
      {:ok, {x1, x2}}
    end
  end

end
```

**After:**
```elixir
defmodule Bhaskara do

  @spec solve(number, number, number) :: {atom, String.t() | {number, number}}
  def solve(a, b, c) do
    delta = (b*b - 4*a*c)

    if delta < 0 do
      {:error, "No real roots"}
    else
      x1 = (-b + delta ** 0.5) / (2*a)
      x2 = (-b - delta ** 0.5) / (2*a)
      {:ok, {x1, x2}}
    end
  end

end
```

**Side-conditions:**
- None: upstream says the refactoring has no preconditions or postconditions and can
  always be used to specify any named function.

## Moving error-handling mechanisms to supervision trees

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4414)

**When:** A process handles errors in a defensive style, such as `try..rescue` in a
`GenServer` callback. Making it a supervised process in a supervision tree ("let it
crash") separates error-handling code from business-rule code: the process no longer
handles the error, because its supervisor monitors it and restarts it.

**Before:**
```elixir
defmodule Counter do
  use GenServer
  ...

  def bump(value, pid_name \\ __MODULE__) do
    GenServer.call(pid_name, {:bump, value})
    get(pid_name)
  end

  ## Callbacks
  ...

  @impl true
  def handle_call({:bump, value}, _from, counter) do
    try do
      {:reply, counter, counter + value}
    rescue
      _e in ArithmeticError -> {:reply, counter, counter}
    end
  end

end
```

**After:** Upstream gives no code here. It links to the
[Unsupervised process](https://github.com/lucasvegi/Elixir-Code-Smells#unsupervised-process)
code smell for a supervised `Counter`, which crashes on a non-numeric `bump/2` value and
is restarted by its supervisor.

**Side-conditions:** None stated.

**Caution (this skill, not upstream):** letting it crash changes results. The `bump/2`
caller exits instead of getting the unchanged counter back, and the restarted process
runs `init/1` again, so the count returns to its initial value. The linked supervisor
starts each `Counter` with `GenServer.start/3`, which does not link it, so that
supervisor never restarts it; a child must start through a `start_link` function.

## From meta to normal function application

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4470)

**When:** Code calls `apply/3`, which takes the module, function name, and argument list
at runtime, although all three are known at compile time. Replace the call with a direct
function call.

**Before:**
```elixir
iex(1)> apply(Enum, :sort, [[4, 3, 2, 1]])
[1, 2, 3, 4]
```

**After:**
```elixir
iex(1)> Enum.sort([4, 3, 2, 1])
[1, 2, 3, 4]
```

**Side-conditions:**
- In the original code, the function that `apply/3` calls and its arguments must be
  defined statically, at compile time.

## Remove unnecessary calls to length/1

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4498)

**When:** A function calls `length/1` in guards to check whether a list is empty. Lists
are linked, so each `length/1` call costs time proportional to the list's size. Pattern
matching on `[]` and `[_|_]` keeps the behavior for proper lists and makes the code more
efficient.

**Before:**
```elixir
defmodule Bar do
  def foo(list) when length(list) == 0 do
    :empty_list
  end

  def foo(list) when length(list) != 0 do
    :non_empty_list
  end
end
```

**After:**
```elixir
defmodule Bar do
  def foo([]) do
    :empty_list
  end

  def foo([_|_]) do
    :non_empty_list
  end
end
```

**Side-conditions:**
- The function receives a list as a parameter and calls `length/1` in guard clauses to
  check whether the list is empty.

**Caution (this skill, not upstream):** `[_|_]` also matches an improper list such as
`[1 | 2]`, which the `length/1` guards rejected with `FunctionClauseError`.

## Add type declarations and contracts

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4550)

**When:** A data structure recurs in typespecs, such as a tuple of three integers in a
`@spec`. A custom type declared with `@type` names the structure and makes the code
easier to read. Typespecs also document the code and prepare it for
[Dialyzer](https://hex.pm/packages/dialyxir).

**Before:**
```elixir
defmodule Foo do

  @spec set_background({integer, integer, integer}) :: atom
  def set_background(rgb) do
    #do something...
    :ok
  end
end
```

**After:**
```elixir
defmodule Foo do

  @typedoc """
    A tuple with three integer elements between 0..255
  """
  @type color :: {red :: integer, green :: integer, blue :: integer}

  @spec set_background(color) :: atom
  def set_background(rgb) do
    #do something...
    :ok
  end
end
```

**Side-conditions:**
- The new type's name (for example `color()`) must be unique. It must differ from every
  predefined basic type (`integer()`, `float()`, `atom()`, and so on) and from every
  custom type in the refactored module, in any other module of the codebase, and in
  imported external libraries.
- The type's name must also differ from the names of functions defined in the module.
  Types and functions do not technically conflict, but a shared name confuses readers,
  so upstream makes this a side-condition too.

## Introduce processes

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4618)

**When:** One process, such as a singleton `GenServer`, serves many clients and becomes
a bottleneck: when calls arrive faster than it handles them, its mailbox overloads, uses
too much memory, and can overflow the BEAM OS process. Introducing concurrent processes
maps parallel processes better onto the problem's parallel activities, which removes the
bottleneck and improves scalability and performance.

**Before:**
```elixir
defmodule Todo.Database do
  use GenServer

  ...

  def start do
    GenServer.start(__MODULE__, nil, name: __MODULE__) #<-- Singleton process!
  end

  def store(key, data) do
    GenServer.cast(__MODULE__, {:store, key, data})
  end

  def handle_cast({:store, key, data}, state) do
    key
    |> file_name()
    |> File.write!(:erlang.term_to_binary(data))

    {:noreply, state}
  end

  ...

end
```

**After:**
```elixir
defmodule Todo.Database do
  use GenServer
  ...

  def handle_cast({:store, key, data}, state) do
    Task.start(fn ->     #<-- Concurrency Introduced!
      key
      |> file_name()
      |> File.write!(:erlang.term_to_binary(data))
    end)

    {:noreply, state}
  end

  ...
end
```

**Side-conditions:** None stated.

**Caution (this skill, not upstream):** one `Task.start/1` per write gives up three
things the single process guaranteed. Writes to the same key can finish out of order,
so an older value can overwrite a newer one. A read through the server right after
`store/2` can miss the write. And a failed write no longer crashes the server, so
nothing reports it. Keep each key's writes in one process, for example with a pool
chosen by key, as the book does.

Example credit: based on code by Saša Jurić in the book "Elixir in Action, 2. ed.",
which also introduces concurrency with a pool of processes.

## Remove processes

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4687)

**When:** Code uses processes, callbacks, and message passing for work a regular module
could do with function calls. Such processes hurt readability and can cause excessive
memory use and bottlenecks as unprocessed messages pile up in the mailbox. Replacing
them with a regular module removes the code smell
[Code organization by process](https://github.com/lucasvegi/Elixir-Code-Smells#code-organization-by-process),
improves the design and readability, and can improve performance.

Upstream gives no code. It points to that smell's entry, where a regular module and
function calls replace processes, callbacks, and message passing.

**Caution (this skill, not upstream):** that example does not meet the side-condition
below. Dropping the process drops the `pid` argument, so `Calculator.add/3` becomes
`add/2`, and a bad argument now raises in the caller instead of exiting it through
`GenServer.call/2`. Treat the change as an interface change and update every caller.

**Side-conditions:**
- Process callbacks must be replaceable with ordinary function calls without changing
  the public interface of the refactored module.

## Add a tag to messages

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4703)

**When:** Processes exchange untagged messages, so the receiver treats every message the
same way whatever its format. Adding tags that identify groups of messages lets the
receiver handle each message by its purpose or format.

**Before:**
```elixir
defmodule Receiver do
  # ...
  def run() do
    receive do
      msg_received -> IO.puts("Message: #{msg_received}")
    after
      30_000 -> IO.puts("Timeout...")
    end
  end
  # ...
end

defmodule Sender do
  # ...
  def send_msg(pid_receiver, msg) do
    send(pid_receiver, msg)
  end
end
```

**After:**
```elixir
defmodule Receiver do
  # ...
  def run() do
    receive do
      {:msg, msg_received} -> IO.puts("Message: #{msg_received}")
      {:sum, {v1, v2}} -> IO.puts("Result: #{v1 + v2}")
      {_, _} -> IO.puts("Won't match!")
    after
      30_000 -> IO.puts("Timeout...")
    end
  end
  # ...
end

defmodule Sender do
  # ...
  def send_msg(pid_receiver, msg, tag \\ :msg) do
    send(pid_receiver, {tag, msg})
  end
end
```

**Side-conditions:**
- The function whose arity changes (for example `Sender.send_msg/3`) must not conflict
  in name and arity with functions already predefined in or imported by the refactored
  module.

**Steps:** `Sender.send_msg/2` becomes `Sender.send_msg/3`, with `tag` defaulting to
`:msg`. Every message becomes a `{tag, msg}` tuple, and `Receiver.run/0` pattern
matches on the tags the system needs.

**Caution (this skill, not upstream):** upstream says existing `send_msg/2` calls keep
their behavior. They still compile, but they now send and return `{:msg, msg}`, so every
receiver must change in the same step. Untagged messages from other senders no longer
match the new `receive` and wait in the mailbox until the timeout.

## Register a process

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4830)

**When:** Senders address a process by its PID, so each sender must know that ID.
Registering the process under a user-defined name lets any process in the system message
it by name and makes the code easier to read. The example reuses `Receiver` and `Sender`
from [Add a tag to messages](#add-a-tag-to-messages).

**Before:**
```elixir
iex(1)> pid = Receiver.create()
#PID<0.320.0>

iex(2)> Sender.send_msg(pid, "Hello World!")
Message: Hello World!
```

**After:**
```elixir
iex(1)> pid = Receiver.create()
#PID<0.320.0>

iex(2)> Process.register(pid, :receiver)

iex(3)> Sender.send_msg(:receiver, "Hello World!")
Message: Hello World!
```

**Side-conditions:**
- The process name must be an atom that no other process in the program already uses.
- The process must not already be registered.
- The process must not have several instances running at the same time.

**Caution (this skill, not upstream):** `Receiver.create/0` spawns `run/0`, which
handles one message and exits, and a name goes away when its process exits. A second
`send_msg(:receiver, ...)` then raises `ArgumentError`, where a send to the dead PID did
nothing. Register only processes that stay alive, or handle the error.

Upstream bases these side-conditions on Huiqing Li et al.,
[this paper](https://doi.org/10.1145/1411273.1411283).

## Behaviour extraction

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4874)

**When:** A function could recur in different modules, playing a special role in each.
Extracting it to a behaviour, similar to Fowler and Beck's Extract Interface, sets a
contract that every implementing module follows. Behaviours also help
static analysis tools such as [Dialyzer](https://hex.pm/packages/dialyxir) understand
the code, offer recommendations, and detect potential issues.

**Before:**
```elixir
defmodule Foo do
  def math_operation(a, b) when is_number(a) and is_number(b) do
    {:ok, a + b}
  end
  def math_operation(_, _), do: {:error, "args not numeric"}

  def print_result(a, b) do
    {_, r} = math_operation(a, b)
    IO.puts("Operation result: #{r}")
  end
end
```

**After:**
```elixir
defmodule Foo do
  # behaviour definition
  @callback math_operation(a :: any(), b :: any()) :: {atom(), any()}

  def print_result(a, b) do
    {_, r} = Sum.math_operation(a, b) # <- new refactoring opportunity!
    IO.puts("Operation result: #{r}")
  end
end

defmodule Sum do
  @behaviour Foo  #<- behaviour implementation

  @impl Foo       #<- behaviour implementation
  def math_operation(a, b) when is_number(a) and is_number(b) do
    {:ok, a + b}
  end
  def math_operation(_, _), do: {:error, "args not numeric"}
end
```

**Side-conditions:**
- The module that defines the behaviour's callbacks (for example `Foo`) must not already
  have callbacks, or functions defined or imported, with the same name as the new
  callbacks (for example `math_operation/2`).
- The module that implements the behaviour (for example `Sum`) must not already have
  functions defined or imported that conflict in name and arity with the behaviour's
  callbacks.

**Steps:** Add a `@callback` for the function to the original module, which becomes
the behaviour definition. Move the function to a new module with
[Moving a definition](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1054),
updating all calls to it. Declare `@behaviour` in the new module, which becomes the
behaviour instance. Upstream shows more: a second instance, `Subtraction`, and
[Generalise a function definition](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L2516)
applied to `print_result/2` so it takes the implementation as an argument instead of
calling `Sum` directly.

Example credit: based on Erlang code in
[this paper](https://dl.acm.org/doi/10.1145/3064899.3064909).

## Behaviour inlining

[Catalog entry](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L4995)

**When:** A behaviour instance implements callbacks that should be eliminated. Moving
the implementation into the behaviour-definition module removes it from the instance.

Upstream gives no code. It says to read the
[Behaviour extraction](#behaviour-extraction) example in reverse, from After to Before.

**Side-conditions:**
- The module that originally defines the behaviour's callbacks must not already have
  functions defined or imported with the same name as the function moved into it.
- To avoid breaking changes, remove a callback definition only if no other module in the
  codebase implements the same behaviour.

**Steps:** Move the function that implements the callback from the behaviour
instance to the behaviour-definition module with
[Moving a definition](https://github.com/lucasvegi/Elixir-Refactorings/blob/e40dc9e5f1b8d775f29dc25c4f47938a9c563770/README.md?plain=1#L1054),
which handles naming conflicts and updates references to the function. If it was the
only callback the instance implemented, remove `@behaviour` from the instance, which
becomes a regular module. If it was the last implementation of the callback in the
codebase, remove the callback from the behaviour definition.

**Reverse:** Upstream calls this the inverse of
[Behaviour extraction](#behaviour-extraction).

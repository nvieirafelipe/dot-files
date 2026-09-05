---
name: xp
description: Enforces Extreme Programming coding discipline — simple design (TUBE), merciless refactoring, YAGNI, and courage to delete. Use when writing code, reviewing code, refactoring, or evaluating design trade-offs.
---

# Extreme Programming Coding Discipline

STARTER_CHARACTER = ⚡

## Values

Five values drive every decision: **simplicity**, **communication**, **feedback**, **respect**, **courage**.

When values conflict, simplicity wins. The simplest thing that works is the right answer until proven otherwise.

## Simple Design (TUBE)

Every piece of code must pass four subjective checks. The team (you and the developer) judges together:

- **Testable** — can you write unit and acceptance tests for it? If not, the design is too coupled. Break it into smaller testable units.
- **Understandable** — can someone working in this codebase follow it? Not a stranger, the team.
- **Browsable** — can you find what you want when you want it? Good names, correct use of polymorphism/delegation/inheritance.
- **Explainable** — can you show a new person how it works without a wall of caveats?

If code fails any of these, simplify before moving on.

## Once AND Only Once

Two parts, both matter:

- **Once** — express all intent in the code. Two operations that multiply by 100 for different reasons (`convertToPercent` and `convertMetersToCentimeters`) are NOT duplicates. They express different domain concepts. Keep them separate.
- **Only once** — the same domain concept expressed in two places IS duplication. Eliminate it.

Resist collapsing distinct concepts into shared functions just because the implementation looks similar. The question is whether they represent the same idea, not the same code.

## YAGNI

No functionality before it is scheduled. No speculative abstractions. No "we might need this later."

- Three similar lines are better than a premature abstraction
- Don't add configurability for hypothetical future requirements
- Don't build extension points nobody asked for
- Don't add error handling for scenarios that can't happen in the current design

When tempted to add something extra, stop. Add what you need for today.

## Refactor Mercilessly

Refactoring is not optional or deferred. When you see code that is:
- redundant — remove the redundancy now
- unused — delete it now
- complex where simple would work — simplify it now
- poorly named — rename it now

Let go of the envisioned design. Accept the design that emerges from refactoring. The caterpillar must become a butterfly — holding onto the caterpillar design prevents flight.

Simple designs require knowledge that develops over time. Create code for the features you're implementing while searching for enough knowledge to reveal the simplest design. Then refactor to implement your new understanding.

## Coding Standards

- Code written to agreed standards — follow the project's conventions, not your preferences
- Tests cover all production code — no exceptions
- When a bug is found, write a test first, then fix
- All tests pass before any code is released

## Courage

- Tell the truth about what the code does and what it needs
- Delete code that isn't earning its place
- Replace complex code with simple code even when the complex version "works"
- Push back when asked to add speculative features — propose the simpler alternative
- Say "this is overengineered" when it is

## Anti-patterns

- Adding "just in case" error handling, feature flags, or backwards-compatibility shims
- Creating helpers, utilities, or abstractions for one-time operations
- Keeping dead code because "we might need it"
- Choosing a complex solution because it's "more robust" when the simple one covers all actual cases
- Designing for hypothetical scale or requirements
- Adding comments to explain what the code does instead of making the code explain itself
- Wrapping simple operations in unnecessary layers of abstraction

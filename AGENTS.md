# Project architecture

@docs/architecture.md

# Project conventions

@docs/project-conventions.md

# Production infrastructure

@docs/production-infrastructure.md

# Commands and tasks

The project uses [mise](https://mise.jdx.dev/) to manage high level configuration and tasks.

@docs/available-tasks.md

## Required first step

Before exploring the codebase for any task, read `docs/architecture.md`. Do this before running file searches, opening source files, or inspecting implementation details so the system boundaries and data flow are in context.

## When to read additional references

- **Read `docs/project-conventions.md`** before writing or refactoring code. Also read it when asked about project style, testing patterns, error handling, SQL optimization, commit messages, or JavaScript conventions.
- **Read `docs/production-infrastructure.md`** before changing deployment config, CI/CD, environment variables, Dockerfiles, or backup strategy. Also read it when asked about hosting, Litestream, Coolify, or production monitoring.
- **Read `docs/available-tasks.md`** before running mise tasks. Read the file to see available tasks, then run `mise run <task> --help` for task-specific options.
- **Read `presto/AGENTS.md`** before changing anything in the `presto/` directory. Also read it when the user mentions "presto", the Pimoroni Presto device, MicroPython, or touch display.

## Documentation writing

- Keep reference documentation factual and concise. Follow the existing file structure, extending current sections, tables, and terminology rather than introducing a new presentation style.
- Begin explanatory documentation with the concrete problem, capability, or operational reason it addresses. Establish why something matters before describing mechanics.
- Prefer specific detail over broad claims: name relevant modules, routes, workers, dependencies, data flows, configuration values, constraints, and verification steps.
- Use functional headings and lists only when they clarify progression, categories, requirements, steps, or tradeoffs.
- Make tradeoffs explicit where they affect maintenance, reliability, portability, failure handling, user experience, or operational complexity.
- Keep recommendations contextual. Describe the conditions under which an approach fits this application instead of presenting choices as universal rules.
- For guides and technical walkthroughs, favour an example-driven progression: context, minimal relevant implementation or procedure, constraints, and verification.
- Use a plain, informed tone. Avoid sales language, unsupported certainty, and conclusions that go beyond the available evidence.

<!-- usage-rules-start -->
<!-- usage_rules-start -->

## usage_rules usage

_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should _thoroughly_ consult before taking any
action. These usage rules contain guidelines and rules _directly from the package authors_.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```

## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```

<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->

## usage_rules:elixir usage

# Elixir Core Usage Rules

## Pattern Matching

- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling

- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid

- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design

- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures

- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing

- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->

## usage_rules:otp usage

# OTP Usage Rules

## GenServer Best Practices

- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication

- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance

- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async

- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- mdex-start -->

## mdex usage

_Fast and extensible Markdown for Elixir_

@deps/mdex/usage-rules.md

<!-- mdex-end -->
<!-- usage-rules-end -->

<!-- BACKLOG.MD GUIDELINES START -->

<CRITICAL_INSTRUCTION>

## Backlog.md Overview (CLI)

This project uses Backlog.md to track features, bugs, and structured work as tasks.

### When to Use Backlog

Create a task when the work requires planning, decisions, or handoff notes.

Ask: "Do I need to think about HOW to do this?"

- Yes: search for an existing task first, then create one if needed.
- No: do the small mechanical change directly.

Create tasks for work like bug fixes that need investigation, feature work, API changes, refactors, or anything that should be reviewed as a commitment. Skip task creation for questions, explanations, quick lookups, and obvious mechanical edits.

### Start Every Request Here

Use this overview to decide what to read or run next. The detailed guides contain the procedure for creating, executing, and finalizing tasks.

Search and read before changing anything:

- `backlog search "query" --plain`
- `backlog task list --status "<todo status>" --plain`
- `backlog task list --status "<active status>" --plain`
- `backlog task list --search "login" --labels frontend,bug --limit 20 --plain`
- `backlog task view ML-123 --plain`

### Detailed Guides

Always read the relevant guide before that part of the workflow. Do not rely on this overview alone for these actions:

- `backlog instructions task-creation`
  -> Read before creating tasks: how to search, scope, and create tasks
- `backlog instructions task-execution`
  -> Read before planning or updating task work: how to plan, update, and work through tasks
- `backlog instructions task-finalization`
  -> Read before finishing tasks: how to verify, summarize, and finish tasks

Use `backlog <command> --help` before unfamiliar operations. Command help includes input fields, read/write behavior, output shape, and examples.

### Core Principle

Backlog tracks committed work: what will be built, fixed, or changed. Use the CLI for Backlog changes so metadata, file names, relationships, and history stay consistent.

Important: Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use Backlog commands so automatic metadata stays complete.

</CRITICAL_INSTRUCTION>

<!-- BACKLOG.MD GUIDELINES END -->

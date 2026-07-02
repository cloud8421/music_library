---
id: ML-36
title: Return controlled errors from genre population
status: Done
assignee: []
created_date: "2026-04-20 08:52"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/142"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-30 · updated 2026-03-30 · closed 2026-03-30_

## Summary

`Records.populate_genres/1` is documented and typed as tuple-based error handling, but it hard-matches `OpenAI.gpt/1` success and therefore crashes on API failures.

## Why This Matters

A transient OpenAI failure becomes an exception path instead of a controlled domain error. The worker and callers are written as if this function follows the normal `{:ok, ...} | {:error, ...}` contract.

## Evidence

- `populate_genres/1` is spec'd as `{:ok, Record.t()} | {:error, Ecto.Changeset.t()}`.
- The implementation does `{:ok, response} = OpenAI.gpt(completion)`.
- `MusicLibrary.Worker.PopulateGenres` uses `with {:ok, updated_record} <- Records.populate_genres(record)` as if the function returns tagged tuples.

## Affected Files

- `lib/music_library/records.ex`
- `lib/music_library/worker/populate_genres.ex`

## Suggested Fix

Make `populate_genres/1` consistently return tagged tuples using `with {:ok, response} <- OpenAI.gpt(completion), {:ok, updated_record} <- Repo.update(...) do ... end`, mapping external API failures into a domain error shape the worker can handle intentionally.

## Acceptance Criteria

<!-- AC:BEGIN -->

- OpenAI/API failures do not raise from `populate_genres/1`.
- The worker behavior is explicit for retryable vs non-retryable failures.
- Tests cover an API failure path.

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 OpenAI/API failures do not raise from `populate_genres/1`.
- [ ] #2 The worker behavior is explicit for retryable vs non-retryable failures.
- [ ] #3 Tests cover an API failure path.

<!-- AC:END -->

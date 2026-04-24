---
id: ML-144
title: Implement magazine issue ingestion pipeline
status: To Do
assignee: []
created_date: '2026-04-22 15:38'
updated_date: '2026-04-24 06:51'
labels:
  - feature
  - magazines
  - ai
  - oban
  - pipeline
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Build a pipeline to ingest music magazine issues (PDF), extract structured metadata (artist mentions, album reviews, upcoming releases, features), and surface relevant information in the app.

## Approach (Approved)
**Approach 1 — Text-first, single LLM pass with structured output:**
- Extract text locally with pdftotext (poppler, shell from Elixir) or [kreuzberg](https://hex.pm/packages/kreuzberg)
- Feed chunks to OpenAI Responses API with JSON schema for structured output
- One Oban worker per issue, one API call per chunk
- Cost estimate: ~$0.01–0.10 per issue with gpt-4o-mini

## Pipeline Overview
1. Upload PDF → store as Asset
2. Enqueue `IngestIssue` worker (new `magazines` queue, concurrency 1)
3. Extract text locally (pdftotext)
4. Split by section boundaries (page breaks, headings)
5. Per-chunk LLM call requesting structured payload:
   - `mentions`: `[{type: "artist"|"album"|"track", name, artist_name?, release_date?, context_snippet}]`
   - `topic`: `"review"|"news"|"upcoming"|"feature"`
6. Persist to new `Magazines` context (Issue, Mention schemas)
7. Resolve each mention against existing records/artists by name (MusicBrainz lookup fallback for unknowns)

## Personalization Layer
- Load collection's artist MBIDs once per issue
- Match mentions by name → MBID (exact match, then fuzzy / MusicBrainz search)
- For matched artists/albums: create Note linked via musicbrainz_id with article snippet
- For unmatched artists in recommendation contexts: queue as wishlist candidates
- Upcoming releases: new schema or flag on notes with reminder job

## Integration Points
- New context: `MusicLibrary.Magazines` with `Issue` and `Mention` schemas
- New Oban queue: `magazines` (concurrency 1)
- Workers: `IngestIssue`, `ExtractArticle`, `ResolveMentions`
- LiveView: `MagazineLive.Index/Show` under main authenticated `live_session`
- Surface mentions on `CollectionLive.Show`, `ArtistLive.Show` ("mentioned in Prog #166, Dec 2025")
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Pipeline can ingest a magazine PDF and extract text without OCR
- [ ] #2 Structured extraction (artist/album mentions, topics) is persisted to database
- [ ] #3 Mentions are resolved against existing collection with MusicBrainz fallback lookup
- [ ] #4 Notes are created for matched artists/albums with article context
- [ ] #5 Magazine mentions surface on record/artist detail pages
- [ ] #6 Cost per issue documented and under budget estimate
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 I can open a page in the application, drag and drop a magazine PDF, and start ingestion
- [ ] #2 For each artist/album in the collection and Wishlist, I can see relevant informational articles coming from ingested magazines
- [ ] #3 I can see a list of ALL ingested items, even those which don't have direct correlation with existing records and artists
<!-- DOD:END -->

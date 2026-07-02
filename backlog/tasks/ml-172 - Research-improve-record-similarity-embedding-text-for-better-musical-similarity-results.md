---
id: ML-172
title: >-
  Research: improve record similarity embedding text for better musical
  similarity results
status: To Do
assignee: []
created_date: "2026-05-09 05:49"
updated_date: "2026-05-11 06:47"
labels:
  - research
dependencies: []
modified_files:
  - lib/music_library/records/similarity.ex
  - lib/music_library/records/record_embedding.ex
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

## Problem

The current record similarity approach (`MusicLibrary.Records.Similarity.text_representation/1`) builds embedding text from artist biographical info (Wikipedia, Discogs, MusicBrainz), genres, Last.fm tags, and similar artists — then uses OpenAI embeddings + cosine distance to find similar records.

This yields poor results. Example: Gotthard's "Made in Switzerland" returns zero similar records at the current 0.45 threshold, despite obvious musical similarity to Mr. Big and other hard rock acts.

**Root cause confirmed:** The actual embedding text for this record is dominated by repetitive Wikipedia biographical prose. Here's the real output:

```
Album: Made in Switzerland
Artists: Gotthard
Genres: hard rock, rock, heavy metal, blues rock, alternative rock
Released: 2006
Type: Live

Gotthard (Switzerland):
Swiss hard rock band. Gotthard is a Swiss hard rock band founded in Lugano
by Steve Lee and Leo Leoni. Their last sixteen albums have all reached number
one in the Swiss album charts... [~200 more chars of biography]
Gotthard is a Swiss hard rock band founded in Lugano by Steve Lee and Leo Leoni.
Tags: hard rock, rock, melodic rock, heavy metal, swiss, switzerland, classic rock
```

Issues visible:

- Wikipedia description + summary are both included and redundant (both say "Swiss hard rock band founded by Steve Lee and Leo Leoni")
- Biographical text is ~300+ chars, while genres+tags are ~100 chars — the musical similarity signal is proportionally tiny
- No Last.fm similar artists appear in this particular embedding text (may need regeneration after similar artists were fetched)
- The embedding model likely weights "Swiss band from Lugano" and chart statistics more than "hard rock / melodic rock / heavy metal"

Meanwhile, the Last.fm similar artists data (Magnum, Thunder, Tesla, etc.) is correctly stored in `ArtistInfo.lastfm_data` and visible on the artist page — so the signal exists but is severely underrepresented.

## Research goals

Investigate and propose alternative approaches:

1. **Text weighting / restructuring** — Give more prominence to genres, Last.fm tags, and similar artists; reduce or restructure biographical text so it doesn't dominate. E.g., deduplicate Wikipedia description+summary, cap bio at 100-150 chars, put genres/tags/similar artists first.
2. **Different embedding strategies** — e.g., separate artist-level and record-level embeddings, or generate embedding text focused purely on musical descriptors rather than biography
3. **Hybrid approaches** — Combine embedding similarity with explicit genre/tag overlap scoring, or use Last.fm similar artists as a direct influence on ranking
4. **Model / parameter tuning** — Explore whether a different OpenAI model, different chunking strategy, or threshold adjustment alone could fix this
5. **External signals** — Could additional data sources (e.g., MusicBrainz genre tags, AllMusic style descriptors) provide better similarity signals?

## Success criteria

- Identify 2-3 promising approaches ranked by expected impact and implementation effort
- For top approach(es), rough out what the new `text_representation` would look like
- Document findings so an implementation task can follow

<!-- SECTION:DESCRIPTION:END -->

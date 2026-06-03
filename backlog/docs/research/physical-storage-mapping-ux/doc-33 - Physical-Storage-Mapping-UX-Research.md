---
id: doc-33
title: Physical Storage Mapping UX Research
type: other
created_date: "2026-06-03 09:16"
updated_date: "2026-06-03 09:41"
tags:
  - research
  - ux
  - physical-storage
  - collection
---

# Physical Storage Mapping UX Research

This research explores how the music collection can reflect where records physically live in a 5×5 IKEA Kallax. It focuses on user experience, use cases, and interface concepts rather than a technical or architectural plan.

## Problem framing

The application knows whether a record is in the collection, but not where that copy can be found in the room. The real-world collection is organized in a finite physical grid, grouped by physical storage category, and roughly alphabetized within each category. The useful product goal is not perfect warehouse precision; it is to make lookup, browsing, and rebalancing easier without turning routine collection maintenance into data entry work.

## Confirmed clarifications

- Shelf labels should be numeric: `1` through `25`.
- Numbering follows the physical reading order: top-left to bottom-right.
- The storage order is:
  1. Vinyl
  2. Special large editions
  3. Blu-rays/DVDs
  4. Special audio editions
  5. CDs
- The exact shelf ranges are known:
  - Vinyl: shelves `1–3`.
  - Special large editions: shelves `4–5`.
  - Blu-rays/DVDs: shelf `6`.
  - Special audio editions: shelf `7`.
  - CDs: shelves `8–16`.
  - Unused shelves: `17–25`.
- Shelf-level location is enough. Exact order inside a shelf does not need to be tracked.
- Order inside a destination shelf does not matter when moving records.
- Temporary states such as “lent out”, “on desk”, or “to file” are not needed.
- Presto should only display the record location, not edit or browse shelves.
- Special editions are not currently tracked in the application and cannot be reliably inferred from format alone.
- Multi-format editions are not automatically special editions. Many thicker multi-format digibooks fit in the CD containers and should stay with CDs unless manually selected otherwise.

## Current physical model

The Kallax has 25 cubbies/shelves:

```text
+------+------+------+------+------+
|  1   |  2   |  3   |  4   |  5   |
+------+------+------+------+------+
|  6   |  7   |  8   |  9   | 10   |
+------+------+------+------+------+
| 11   | 12   | 13   | 14   | 15   |
+------+------+------+------+------+
| 16   | 17   | 18   | 19   | 20   |
+------+------+------+------+------+
| 21   | 22   | 23   | 24   | 25   |
+------+------+------+------+------+
```

Confirmed shelf usage:

- Vinyl: 3 shelves, `1–3`.
- Special large editions: 2 shelves, `4–5`.
- Blu-rays/DVDs: 1 shelf, `6`.
- Special audio editions: 1 shelf, `7`.
- CDs: 9 shelves, `8–16`, with containers allowing up to 120 jewel cases per shelf.
- Unused: 9 shelves, `17–25`.
- CD shelves are not full, and many CD records are not standard jewel cases.

Confirmed map:

```text
+----+-----+----+------+------+
| V  | V   | V  | L-SE | L-SE |
| 1  | 2   | 3  | 4    | 5    |
+----+-----+----+------+------+
| BR | AUD | CD | CD   | CD   |
| 6  | 7   | 8  | 9    | 10   |
+----+-----+----+------+------+
| CD | CD  | CD | CD   | CD   |
| 11 | 12  | 13 | 14   | 15   |
+----+-----+----+------+------+
| CD | —   | —  | —    | —    |
| 16 | 17  | 18 | 19   | 20   |
+----+-----+----+------+------+
| —  | —   | —  | —    | —    |
| 21 | 22  | 23 | 24   | 25   |
+----+-----+----+------+------+
```

## Suggested location language

Use the numeric shelf label as the primary identifier:

```text
Shelf 12
```

For clarity, the UI can optionally add spatial helper text:

```text
Shelf 12 · row 3, column 2
```

Presto can use the same label, plus a highlighted mini-grid. The number should remain the main location because it matches the requested shelf naming scheme.

## UX principles

1. **Shelf-level is the right granularity.** The requested workflows need to know which cubby to open, not the exact position inside it.
2. **Generated locations should be visibly provisional.** A heuristic prefill should use confidence labels such as `estimated`, `reviewed`, and `manual`.
3. **Bulk movement should match physical work.** Interfaces should say “move these records to shelf 14” rather than “batch update rows”.
4. **The map should show uncertainty and fullness.** Empty, estimated, crowded, and reviewed shelves should look different.
5. **Special editions need manual curation.** They are physical storage groups, not dependable metadata formats.
6. **Rebalancing should preview consequences.** Before applying a move, show source and destination counts and the affected records.
7. **The UI should tolerate rough alphabetical order.** The physical collection is “roughly” sorted, so the app should not imply exact within-shelf ordering.
8. **Do not over-model temporary states.** The requested experience is about permanent shelf location, not lending or staging workflows.
9. **Unused shelves should still be visible.** Shelves `17–25` are part of the physical map and useful for future expansion or rebalancing, even if they contain no records now.

## Primary use cases

### 1. Find a record in the room

**Trigger:** The user opens a record detail page or views a record on Presto and wants to retrieve it.

**UX need:** Show a compact, unambiguous location near the record identity.

```text
Physical location
┌────────────────────────────┐
│ Shelf 12                   │
│ row 3 · column 2           │
│ CDs · estimated assignment │
└────────────────────────────┘
```

For Presto, the same information should be more visual:

```text
Kallax: shelf 12

[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ]
[ ][█][ ][ ][ ]
[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ]
```

### 2. Assign or correct one record

**Trigger:** A generated assignment is wrong, a special edition needs to be manually selected, or a newly added record is placed physically.

**UX need:** The record edit form should provide a simple shelf picker, not a free-text field.

```text
Location
Selected shelf: 7

[ 1] [ 2] [ 3] [ 4] [ 5]
[ 6] [x7] [ 8] [ 9] [10]
[11] [12] [13] [14] [15]
[16] [17] [18] [19] [20]
[21] [22] [23] [24] [25]

Storage group: Special audio edition
Confidence: manual

[Clear location] [Save]
```

A record could also show “location unknown” for edge cases. Since temporary states are not needed, the picker should avoid states like “lent out” or “to file”.

### 3. Initial prefill from heuristics

**Trigger:** The user wants to populate existing collection records with likely shelves.

**UX need:** A guided wizard that previews assumptions and lets the user fix special-edition selections before applying.

Possible flow:

```text
Step 1: Confirm shelf groups

Group                   Shelves      Assignment source
Vinyl                   1–3          format-based
Special large editions  4–5          manual selection
Blu-rays/DVDs           6            format-based
Special audio editions  7            manual selection
CDs                     8–16         format-based, after manual special selection
Unused                  17–25        no assignment
```

```text
Step 2: Select special editions

Special large editions · shelves 4–5
[Search collection________________]
[ ] Artist — Large-format box
[ ] Artist — Oversized edition

Special audio editions · shelf 7
[Search collection________________]
[ ] Artist — SACD box
[ ] Artist — Special audio package

These choices override the normal format-based group.
```

```text
Step 3: Preview generated boundaries

Vinyl · shelves 1–3 · 142 matched records
1: A–D       48 records
2: E–P       47 records
3: Q–Z       47 records

Blu-rays/DVDs · shelf 6 · 64 matched records
6: A–Z       64 records

Special large editions · shelves 4–5 · manual records
4: selected special large editions
5: selected special large editions

Special audio editions · shelf 7 · manual records
7: selected special audio editions

CDs · shelves 8–16 · 630 matched records
8: A–Be      70 records
9: Bi–Br     70 records
...
16: Wo–Z     70 records

Unassigned or ambiguous: 23 records
Unused shelves: 17–25
```

Good prefill behavior:

- Only apply to collected records, not wishlist records.
- Sort within groups by artist sort name, then title, then release year if needed.
- Assign vinyl, Blu-ray/DVD, and CD groups primarily from format.
- Let manually selected special large/audio editions override their format-based group.
- Do not automatically classify multi-format releases as special editions.
- Split vinyl and CD records across their configured shelf ranges by count, not by exact capacity, unless the user provides known per-shelf counts.
- Assign all Blu-ray/DVD records to shelf `6` unless the user manually changes individual records.
- Leave ambiguous records unassigned rather than pretending the heuristic knows.
- Mark all generated values as `estimated` until reviewed or manually changed.

The most important review affordance is a boundary editor:

```text
CD shelf boundaries

 8 | Aaliyah ─────────────── Beck
 9 | Belle and Sebastian ─── Broadcast
10 | Built to Spill ──────── Can
...
16 | Wilco ───────────────── Zwan

Adjust boundary:
Shelf 8 ends after [Beck v]
Shelf 9 starts at [Belle and Sebastian v]
```

### 4. Move or rebalance records between shelves

**Trigger:** A shelf becomes crowded, new purchases are inserted alphabetically, or storage is physically rearranged.

**UX need:** Bulk movement should support arbitrary shelf changes without caring about precise order inside the destination shelf.

Useful move modes:

1. Move selected records.
2. Move records from first-to-last selection within a shelf.
3. Move the first or last N records from a shelf.
4. Move all records matching a query/filter.
5. Move an entire shelf to another shelf.

Example modal:

```text
Move records

From: Shelf 14 · CDs · 96 records
Move: ( ) selected records: 17
      ( ) range: [first record v] through [last record v]
      (x) last [20] records on shelf

To:   Shelf 15 · CDs · 61 records

Preview:
Shelf 14: 96 → 76 records
Shelf 15: 61 → 81 records
Affected records: Shellac → Yo La Tengo

[Cancel] [Apply move]
```

Because within-shelf order is not tracked, the UI should not ask whether records go at the beginning or end of the destination shelf.

### 5. Browse collection by physical space

**Trigger:** The user wants the app to mirror the Kallax and browse by shelf.

**UX need:** Add a collection display mode that uses the physical layout as the primary navigation surface.

```text
Collection display: [Grid] [List] [Shelf map]

Kallax
┌────────────┬────────────┬────────────┬────────────┬────────────┐
│ 1 Vinyl    │ 2 Vinyl    │ 3 Vinyl    │ 4 L-Spec   │ 5 L-Spec   │
│ 48 records │ 47 records │ 47 records │ 21 records │ 20 records │
│ A–D        │ E–P        │ Q–Z        │ manual     │ manual     │
├────────────┼────────────┼────────────┼────────────┼────────────┤
│ 6 BR/DVD   │ 7 A-Spec   │ 8 CD       │ 9 CD       │ 10 CD      │
│ 64 records │ 13 records │ 70 records │ 70 records │ 70 records │
│ A–Z        │ manual     │ A–Be       │ Bi–Br      │ Bu–Co      │
├────────────┼────────────┼────────────┼────────────┼────────────┤
│ 11 CD      │ 12 CD      │ 13 CD      │ 14 CD      │ 15 CD      │
│ ...        │ ...        │ ...        │ ...        │ ...        │
├────────────┼────────────┼────────────┼────────────┼────────────┤
│ 16 CD      │ 17 Empty   │ 18 Empty   │ 19 Empty   │ 20 Empty   │
│ ...        │            │            │            │            │
├────────────┼────────────┼────────────┼────────────┼────────────┤
│ 21 Empty   │ 22 Empty   │ 23 Empty   │ 24 Empty   │ 25 Empty   │
│            │            │            │            │            │
└────────────┴────────────┴────────────┴────────────┴────────────┘
```

Shelf cells can communicate:

- Shelf number.
- Dominant storage group.
- Record count.
- Alphabetical range, where meaningful.
- Fullness indicator.
- Assignment quality: estimated/manual/mixed.
- Warning state for overcrowded or unreviewed shelves.
- Empty state for unused shelves `17–25`.

Clicking a cell opens a shelf detail panel:

```text
Shelf 12 · CDs
72 records · estimated/mixed
Range: Fugazi → Hüsker Dü

[Search within shelf________]
[Move records] [Mark reviewed]

Fugazi — Repeater
Galaxie 500 — On Fire
Godspeed You! Black Emperor — F♯ A♯ ∞
...

← Shelf 11              Shelf 13 →
```

### 6. Audit a shelf

**Trigger:** The user is physically in front of one cubby and wants to check whether the app agrees.

**UX need:** A shelf checklist, probably optimized for mobile/tablet browser first.

```text
Audit shelf 12

Expected: 70 CDs · Brian Eno → Can

[✓] Brian Eno — Another Green World
[✓] Broadcast — Tender Buttons
[ ] Can — Ege Bamyasi
[?] Not here
[+] Found extra record

[Save audit notes]
```

This does not need to be part of the first version, but it is a natural extension once locations exist. It should still remain shelf-level only.

### 7. See location on Presto

**Trigger:** A record detail is displayed on the Presto companion device.

**UX need:** Show the shelf label without overwhelming the small screen.

Possible compact display:

```text
The Cure
Disintegration

Shelf 10
CDs

[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][█]
[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ]
```

If the location is unknown:

```text
Location unknown
Update in web app
```

Presto should display location only. Editing, browsing, and auditing should stay in the web application.

## Interface options

### Option A: Location card on record detail

Best for retrieval and correction.

```text
┌─────────────────────────────────────────────┐
│ Physical location                           │
│ Shelf 12                                    │
│ CDs · estimated from initial prefill         │
│                                             │
│ [Change shelf] [Mark correct]               │
└─────────────────────────────────────────────┘
```

### Option B: Shelf picker mini-map

Best for editing one record.

```text
Choose shelf

[ 1] [ 2] [ 3] [ 4] [ 5]
[ 6] [ 7] [ 8] [ 9] [10]
[11] [12] [13] [14] [15]
[16] [17] [18] [19] [20]
[21] [22] [23] [24] [25]

Selected: 12
```

### Option C: Shelf map display mode

Best for physical browsing.

```text
Display as:  Grid | List | Shelf map
Sort:        Physical order
Filter:      [all storage groups v]
```

### Option D: Boundary editor

Best for heuristic prefill and later rebalancing.

```text
CD shelves

 8 [A—Be]     9 [Bi—Br]    10 [Bu—Co]    11 [Cr—Da]    12 [De—El]
13 [Em—Fi]   14 [Fl—Go]    15 [Gr—Ha]    16 [He—Z]

[Adjust boundaries] [Preview assignment]
```

### Option E: Bulk move assistant

Best for arbitrary shifts between shelves.

```text
Rebalance assistant

I want to move:
[x] the last N records from a shelf
[ ] a selected range
[ ] everything from one shelf
[ ] records matching a search

N: [ 25 ]
From: [14 v]
To:   [15 v]

[Preview]
```

### Option F: Manual special-edition selector

Best for the two special storage groups, because they are not reliably format-derived.

```text
Special edition assignment

Storage group: [Special large editions v]
Target shelves: 4–5

[Search collection________________]

[ ] Artist — Oversized deluxe box
[ ] Artist — 7-inch box set
[ ] Artist — Thick special package

[Assign selected to group]
```

This selector should be available during prefill and later from the shelf-map view.

## Heuristic prefill considerations

### Format grouping

A practical first pass could classify records into physical storage groups:

| Physical group         | Shelves | Likely source                                       | UX concern                                                                                            |
| ---------------------- | ------- | --------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Vinyl                  | 1–3     | Application format contains vinyl/LP-like values    | Should be reviewable because format text may vary.                                                    |
| Special large editions | 4–5     | Manual selection                                    | Format is not enough; size/packaging is the deciding factor.                                          |
| Blu-rays/DVDs          | 6       | Application format contains Blu-ray/DVD-like values | Should be separated before CDs because it physically sits earlier in the Kallax.                      |
| Special audio editions | 7       | Manual selection                                    | Format is not enough; these are physically separated because of packaging/category, not app metadata. |
| CDs                    | 8–16    | Application format contains CD-like values          | Packaging size varies; count-based split may be approximate.                                          |
| Unused                 | 17–25   | No assignment                                       | Should appear empty/reserved in the shelf map.                                                        |
| Unknown                | —       | Missing, mixed, or unsupported format               | Should remain unassigned for review.                                                                  |

Manual special-edition selection should override format grouping. For example, a CD-format record manually marked as a special audio edition should be assigned to shelf `7`, while a thick multi-format digibook that fits in a CD container should remain in the CD group across shelves `8–16`.

### Distribution strategy

The safest heuristic is count-based distribution across configured shelves, with optional capacity hints.

For CDs, avoid assuming 120 records per shelf means the shelf should be filled to 120. The CD containers allow that maximum, but the current shelves are not full and many records are not standard jewel cases. An even spread across the 9 configured CD shelves (`8–16`) is more likely to approximate the current physical layout.

For Blu-rays/DVDs, all format-matched records should start on shelf `6`. For the two manual special-edition groups, the prefill experience should ask the user to select records before assigning them to shelves `4–5` or `7`.

### Confidence labels

A location should carry a user-facing confidence state:

```text
estimated  — assigned by prefill or heuristic
reviewed   — user confirmed shelf contents or boundary
manual     — user explicitly set this record's shelf
unknown    — no location yet
```

This helps avoid confusing “the app guessed” with “the app knows”.

## Edge cases to account for in UX

- Records with multiple formats or vague format metadata.
- Box sets and special editions that consume more space than a normal record.
- Multi-format digibooks that should still live with CDs.
- Duplicate copies of the same release.
- Multiple physical copies of the same record.
- Wishlist records, which should usually have no physical location.
- Alphabetical exceptions intentionally stored out of order.
- Empty shelves reserved for future growth.

## Recommended product shape

Start with a simple, forgiving system:

1. A fixed 5×5 Kallax map labelled `1`–`25`.
2. Configured shelf groups: vinyl `1–3`, special large editions `4–5`, Blu-rays/DVDs `6`, special audio editions `7`, CDs `8–16`, unused `17–25`.
3. A location card on record detail pages.
4. A shelf picker for individual edits.
5. A shelf-map display mode for the collection.
6. A prefill wizard that assigns estimated shelves by configured group ranges and alphabetical order.
7. Manual selection interfaces for special large editions and special audio editions.
8. A bulk move assistant for moving selected records, ranges, first/last N records, or entire shelves.
9. A compact Presto location display with a highlighted mini-grid.

Avoid tracking exact intra-shelf position initially. It would add maintenance burden and may be misleading because the physical order is only approximate. Presto should remain read-only for location display.

## Remaining open questions

1. Do Blu-ray/DVD records map cleanly to existing application format values?
2. Should special large editions and special audio editions be shown as two separate storage group labels everywhere, or only during prefill/editing?
3. Where should manual special-edition selection be easiest: record detail, shelf map, prefill wizard, or all three?
4. Should unused shelves `17–25` be selectable immediately for future rebalancing, or visually treated as reserved/empty until records are moved there?

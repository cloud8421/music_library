# Music Library

<!--toc:start-->

- [Music Library](#music-library)
  - [Features](#features)
  - [Screenshots](#screenshots)
    - [Stats](#stats)
    - [Collection](#collection)
    - [Searching for a record to add](#searching-for-a-record-to-add)
    - [Edit a record in the collection](#edit-a-record-in-the-collection)
    - [View a record's details in the collection](#view-a-records-details-in-the-collection)
    - [View a record's tracklist](#view-a-records-tracklist)
    - [Adding a record in the wishlist](#adding-a-record-in-the-wishlist)
    - [View an artist's details](#view-an-artists-details)
    - [View the scrobble activity](#view-the-scrobble-activity)
  - [Setup](#setup)
  - [Environment configuration](#environment-configuration)
  - [Running the application](#running-the-application)
  - [Deployment](#deployment)
  - [CI](#ci)
  - [Architecture](#architecture)
  - [Favicons](#favicons)
  <!--toc:end-->

## Features

- Add records from MusicBrainz, with optional override of specific pieces of data
- Manage a collection and a wishlist of records, with ways to quickly search
  and filter based on records' metadata
- Integration with Last.fm:
  - display latest scrobbles, and where possible
    connect them with records in the collection or wishlist
  - scrobble a record
  - store a local copy of the complete scrobble history, and setup rules to fix its data as needed
- Some basic stats
- All data stored in a single SQLite database for portability and ease of backup/restore

## Screenshots

### Stats

![Stats](.github/screenshots/stats.png)

### Collection

![Collection](.github/screenshots/collection.png)

### Searching for a record to add

![Searching for a Record to add](.github/screenshots/record-search.png)

### Edit a record in the collection

![Edit a record in the collection](.github/screenshots/collection-edit-record.png)

### View a record's details in the collection

![View a record's details in the collection](.github/screenshots/collection-record-details.png)

### View a record's tracklist

![View a record's tracklist](.github/screenshots/record-tracklist.png)

### Adding a record in the wishlist

![Adding a record in the wishlist](.github/screenshots/wishlist-import-record.png)

### View an artist's details

![View an artist's details](.github/screenshots/artist-details.png)

### View the scrobble activity

![View the scrobble activity](.github/screenshots/scrobble-activity.png)

## Setup

The project is managed and configured via [mise-en-place](https://mise.jdx.dev):

- `mise install` will pull the correct Erlang, Elixir and Node.js versions
- `mise run dev:setup` will setup dependencies and database structure

> [!IMPORTANT]
> The project uses [Fluxon UI](https://fluxonui.com/), so it requires a valid
> set of credentials. See the `env` section in `mise.toml` for the required
> environment variables.

It's recommended to use the git hooks included in the project. Install with:

`mise generate git-pre-commit --write --task=dev:precommit`

## Environment configuration

Required environment variables for development are listed in `mise.toml`.

You can create a `mise.local.toml` with the required variables (sample values
are included at the top of `mise.toml`).

For production, please see `compose.yaml` for a list of required variables.

## Running the application

Start the Phoenix endpoint with `mise run console` (along with an attached IEx session).

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
The default password for development is `change me`.

## Deployment

The application is deployed via Coolify, using a Docker Compose strategy.

## CI

See the `.github` folder.

## Architecture

See the `docs` folder.

## Favicons

This favicon was generated using the following graphics from Twitter Twemoji:

- Graphics Title: 1f4bd.svg
- Graphics Author: Copyright 2020 Twitter, Inc and other contributors (<https://github.com/twitter/twemoji>)
- Graphics Source: <https://github.com/twitter/twemoji/blob/master/assets/svg/1f4bd.svg>
- Graphics License: CC-BY 4.0 (<https://creativecommons.org/licenses/by/4.0/>)

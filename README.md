# Music Library

<!--toc:start-->
- [Music Library](#music-library)
  - [Features](#features)
  - [Screenshots](#screenshots)
    - [Stats](#stats)
    - [Collection](#collection)
    - [Edit a record in the collection](#edit-a-record-in-the-collection)
    - [View a record's details in the collection](#view-a-records-details-in-the-collection)
    - [Importing a record in the wishlist](#importing-a-record-in-the-wishlist)
  - [Setup](#setup)
  - [Environment configuration](#environment-configuration)
  - [Running the application](#running-the-application)
  - [Deployment](#deployment)
  - [CI](#ci)
  - [Favicons](#favicons)
<!--toc:end-->

## Features

- Import records from MusicBrainz, with optional override of specific pieces of data
- Manage a collection and a wishlist of records, with ways to quickly search
  and filter based on records' metadata
- Integration with Last.fm (display latest scrobbles, and where possible
  connect them with records in the collection or wishlist)
- Some basic stats
- All data stored in a single SQLite database for portability and ease of backup/restore
- Ideal for deployment on a server with limited resources (1CPU, 512MB RAM)

## Screenshots

### Stats

![Stats](.github/screenshots/stats.png)

### Collection

![Collection](.github/screenshots/collection.png)

### Edit a record in the collection

![Edit a record in the collection](.github/screenshots/collection-edit-record.png)

### View a record's details in the collection

![View a record's details in the collection](.github/screenshots/collection-record-details.png)

### Importing a record in the wishlist

![Importing a record in the wishlist](.github/screenshots/wishlist-import-record.png)

## Setup

Run `mix setup` to install and setup dependencies.

## Environment configuration

The application requires the following environment variables:

- `LAST_FM_USER`: the Last.fm username used to populate the Scrobble Activity
- `LAST_FM_API_KEY` (secret): the Last.fm API key used to fetch the Scrobble Activity
- `OPENAI_KEY` (secret): the OpenAI API key used for specific features like populating genres, etc.

In production, the application also requires:

- `LOGIN_PASSWORD` (secret): the password used for accessing the application.

The application is setup to use [direnv](https://direnv.net/).

The `.envrc` file loads two other files: `.envrc.local` file for configuration
variables, and a `.secrets` file for secrets.

You can create them and populate them with the necessary environment variables.

## Running the application

Start the Phoenix endpoint with `mix phx.server` or inside IEx with
`iex -S mix phx.server`.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
The default password for development is `change me`.

## Deployment

The application is setup for deployment on Fly.io - just make sure you edit
`fly.toml` to match your app name, domain, etc.

## CI

See the `.github` folder.

## Favicons

This favicon was generated using the following graphics from Twitter Twemoji:

- Graphics Title: 1f4bd.svg
- Graphics Author: Copyright 2020 Twitter, Inc and other contributors (<https://github.com/twitter/twemoji>)
- Graphics Source: <https://github.com/twitter/twemoji/blob/master/assets/svg/1f4bd.svg>
- Graphics License: CC-BY 4.0 (<https://creativecommons.org/licenses/by/4.0/>)

---
id: ML-75
title: Add Content-Security-Policy header to browser pipeline
status: Done
assignee: []
created_date: "2026-04-20 08:56"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/100"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-07 · updated 2026-03-07 · closed 2026-03-07_

Sobelow reports missing CSP on the browser pipeline (`router.ex:14`). Add a basic CSP via `put_secure_browser_headers/2`.

Currently the app does not set a `Content-Security-Policy` header, which is a defense-in-depth measure against XSS and other injection attacks.

<!-- SECTION:DESCRIPTION:END -->

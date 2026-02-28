# Home Sections API — Backend Specification

> **Purpose:** Make everything below the "Local News" section on the app home page fully server-controlled — no app release required to add, remove, reorder, rename, or restyle sections.
>
> **Base URL:** `https://ratemymantri.sallytion.qzz.io`
>
> **Last updated:** 2026-02-28

---

## Table of Contents

- [Home Sections API — Backend Specification](#home-sections-api--backend-specification)
  - [Table of Contents](#table-of-contents)
  - [1. Problem / Motivation](#1-problem--motivation)
  - [2. Endpoint](#2-endpoint)
  - [3. Request](#3-request)
    - [Query Parameters](#query-parameters)
    - [Example Request](#example-request)
  - [4. Response Schema](#4-response-schema)
    - [Top-level](#top-level)
    - [Section Object](#section-object)
  - [5. Section Types](#5-section-types)
    - [`webview_banner`](#webview_banner)
    - [Future Types (define these when needed)](#future-types-define-these-when-needed)
  - [6. URL Templates](#6-url-templates)
  - [7. Icon Reference](#7-icon-reference)
  - [8. Full Example Response](#8-full-example-response)
    - [Example: Hiding the Games section (no app release needed)](#example-hiding-the-games-section-no-app-release-needed)
    - [Example: Adding a new "Elections" section](#example-adding-a-new-elections-section)
  - [9. Caching](#9-caching)
    - [Server-side headers](#server-side-headers)
    - [Client-side behaviour](#client-side-behaviour)
    - [Separate cache per `lang` + `theme`](#separate-cache-per-lang--theme)
  - [10. Error Handling \& Fallback](#10-error-handling--fallback)
  - [11. Frontend Behaviour (Flutter side)](#11-frontend-behaviour-flutter-side)
  - [12. What the Backend Can Change Without an App Release](#12-what-the-backend-can-change-without-an-app-release)
  - [13. Migration from Current Hardcoded Setup](#13-migration-from-current-hardcoded-setup)
    - [Phase 1 — Backend implements the endpoint](#phase-1--backend-implements-the-endpoint)
    - [Phase 2 — Frontend switches over](#phase-2--frontend-switches-over)
    - [Phase 3 — Hardcoded code removed](#phase-3--hardcoded-code-removed)
  - [HTTP Response Summary](#http-response-summary)

---

## 1. Problem / Motivation

Currently the home page has two hardcoded banner sections (Noticeboard and Games) baked into the Flutter app. Adding a new section, hiding one, changing its name, reordering them, or pointing them to a different URL requires a new app release to both Play Store and App Store.

This API replaces all of that. The Flutter app will call one endpoint on startup, receive a list of sections to display, and render them in order. The backend has full control over the entire section list at all times.

---

## 2. Endpoint

```
GET /api/home/sections
```

---

## 3. Request

### Query Parameters

| Parameter | Type   | Required | Default | Description                                      |
| --------- | ------ | -------- | ------- | ------------------------------------------------ |
| `lang`    | string | No       | `en`    | User's language code. Server uses this to return translated `title` and `webview_title` strings. Same codes as the existing banner API: `en`, `hi`, `mr`, `ta`, `te`, `kn`, `ml`, `bn`, `gu`, `pa`. |
| `theme`   | string | No       | `light` | `light` or `dark`. Server uses this to resolve `banner_image_url` and `webview_url` where needed. |
| `v`       | string | No       | —       | App version string (e.g. `"1.4.2"`). Optional, for future version-gated sections. |

### Example Request

```
GET /api/home/sections?lang=hi&theme=dark&v=1.4.2
```

---

## 4. Response Schema

### Top-level

```json
{
  "sections": [ ...Section[] ],
  "ttl": 300
}
```

| Field      | Type     | Description                                                                            |
| ---------- | -------- | -------------------------------------------------------------------------------------- |
| `sections` | array    | Ordered list of sections to display. Render top-to-bottom in the order given. Empty array = show nothing. |
| `ttl`      | integer  | Seconds the client should cache this response before re-fetching. Backend controls freshness. Typical value: `300` (5 minutes). |

---

### Section Object

```json
{
  "id":              "noticeboard",
  "type":            "webview_banner",
  "visible":         true,
  "order":           1,
  "title":           "सूचना पटल",
  "icon":            "campaign_outlined",
  "banner_image_url":"https://ratemymantri.sallytion.qzz.io/api/banner.png?theme=dark",
  "webview_url":     "https://ratemymantri.sallytion.qzz.io/api/banner/noticeboard.html?lang=hi&theme=dark",
  "webview_title":   "सूचना पटल"
}
```

| Field              | Type    | Required | Description |
| ------------------ | ------- | -------- | ----------- |
| `id`               | string  | Yes      | Stable unique identifier for this section (snake_case). Used by the app for keying, analytics, and error reporting. Never change an `id` once it is live. |
| `type`             | string  | Yes      | Determines how the app renders this section. See [Section Types](#5-section-types). |
| `visible`          | boolean | Yes      | `false` = the app skips this section entirely (renders nothing). Use this to toggle a section on/off without removing it from the list. |
| `order`            | integer | Yes      | Display order. Sections are sorted ascending by this value. It is the backend's responsibility to return them pre-sorted; the app will render them in the order received. |
| `title`            | string  | Yes      | Section heading shown in the card. Already translated by the backend based on the `?lang` param. |
| `icon`             | string  | Yes      | Material icon name string. See [Icon Reference](#7-icon-reference). |
| `banner_image_url` | string  | Yes (for `webview_banner`) | Fully-resolved URL for the banner preview image shown in the card. Theme is already applied — no placeholders. |
| `webview_url`      | string  | Yes (for `webview_banner`) | Fully-resolved URL the app loads in the WebView when the user taps. Language and theme are already appended — no placeholders. |
| `webview_title`    | string  | Yes (for `webview_banner`) | Title shown in the WebView screen's AppBar. Already translated. |

> **Key design principle:** Every URL in the response is **fully resolved** — the app substitutes nothing. The backend already knows the lang and theme from the query params, so it builds the complete URLs and returns them. The app treats them as opaque strings and loads them as-is.

---

## 5. Section Types

Only one type is used today. Define more types later as needed — the app will ignore unknown types gracefully (see §11).

### `webview_banner`

A tappable card with:
- A banner image at the top (`banner_image_url`)
- A title row with an icon and the section heading (`title`, `icon`)
- Tapping anywhere on the card opens a full-screen WebView (`webview_url`) with an AppBar titled `webview_title`

This is the type that currently covers both the Noticeboard and Games sections.

### Future Types (define these when needed)

| Type              | Proposed rendering                                              |
| ----------------- | --------------------------------------------------------------- |
| `link_banner`     | Same card layout but opens URL in device browser, not WebView   |
| `announcement`    | Inline text card, no banner image, no tap action                |
| `poll`            | Inline yes/no vote card backed by a backend poll endpoint       |

The app must **silently skip** any `type` value it does not recognise, so future types can be introduced without breaking older app versions.

---

## 6. URL Templates

There are no placeholders — all URLs in the response are fully resolved by the backend. However, as an internal convention you may want to build them like this on the server:

```
banner_image_url = base + "/api/banner.png?theme=" + theme
webview_url      = base + "/api/banner/noticeboard.html?lang=" + lang + "&theme=" + theme
```

Since the backend controls the URL shape entirely, you can change URL structure in the future by just returning different strings in the API response — as long as those URLs keep working, the app needs no change.

---

## 7. Icon Reference

The `icon` field must be one of the following strings (these are the Material Icons the app recognises). Add more here as needed — the app will fall back to a default icon (`►`) for any unknown value.

| `icon` value              | Visual                          | Use case              |
| ------------------------- | ------------------------------- | --------------------- |
| `campaign_outlined`       | Megaphone / announcement        | Noticeboard           |
| `sports_esports_outlined` | Game controller                 | Games / Quiz          |
| `notifications_outlined`  | Bell                            | Alerts                |
| `info_outline`            | Info circle                     | Informational content |
| `star_outline`            | Star                            | Featured / Top picks  |
| `emoji_events_outlined`   | Trophy                          | Leaderboard           |
| `chat_bubble_outline`     | Chat bubble                     | Discussion / Forum    |
| `poll_outlined`           | Bar chart                       | Polls / Surveys       |
| `article_outlined`        | Document                        | Articles / Blog       |
| `video_library_outlined`  | Video library                   | Video content         |

---

## 8. Full Example Response

Request:
```
GET /api/home/sections?lang=hi&theme=dark
```

Response (`200 OK`, `Content-Type: application/json`):

```json
{
  "sections": [
    {
      "id": "noticeboard",
      "type": "webview_banner",
      "visible": true,
      "order": 1,
      "title": "सूचना पटल",
      "icon": "campaign_outlined",
      "banner_image_url": "https://ratemymantri.sallytion.qzz.io/api/banner.png?theme=dark",
      "webview_url": "https://ratemymantri.sallytion.qzz.io/api/banner/noticeboard.html?lang=hi&theme=dark",
      "webview_title": "सूचना पटल"
    },
    {
      "id": "games",
      "type": "webview_banner",
      "visible": true,
      "order": 2,
      "title": "खेल",
      "icon": "sports_esports_outlined",
      "banner_image_url": "https://ratemymantri.sallytion.qzz.io/api/banner.png?theme=dark",
      "webview_url": "https://ratemymantri.sallytion.qzz.io/api/banner/game.html?lang=hi&theme=dark",
      "webview_title": "खेल"
    }
  ],
  "ttl": 300
}
```

### Example: Hiding the Games section (no app release needed)

```json
{
  "sections": [
    {
      "id": "noticeboard",
      "type": "webview_banner",
      "visible": true,
      "order": 1,
      "title": "सूचना पटल",
      "icon": "campaign_outlined",
      "banner_image_url": "https://ratemymantri.sallytion.qzz.io/api/banner.png?theme=dark",
      "webview_url": "https://ratemymantri.sallytion.qzz.io/api/banner/noticeboard.html?lang=hi&theme=dark",
      "webview_title": "सूचना पटल"
    },
    {
      "id": "games",
      "type": "webview_banner",
      "visible": false,
      "order": 2,
      "title": "खेल",
      "icon": "sports_esports_outlined",
      "banner_image_url": "https://ratemymantri.sallytion.qzz.io/api/banner.png?theme=dark",
      "webview_url": "https://ratemymantri.sallytion.qzz.io/api/banner/game.html?lang=hi&theme=dark",
      "webview_title": "खेल"
    }
  ],
  "ttl": 60
}
```

> **Tip:** Lower the `ttl` when you intend to toggle something quickly (e.g. `60` seconds). Use `300` or more for stable content.

### Example: Adding a new "Elections" section

```json
{
  "sections": [
    {
      "id": "elections_2026",
      "type": "webview_banner",
      "visible": true,
      "order": 0,
      "title": "चुनाव 2026",
      "icon": "poll_outlined",
      "banner_image_url": "https://ratemymantri.sallytion.qzz.io/api/elections/banner.png?theme=dark",
      "webview_url": "https://ratemymantri.sallytion.qzz.io/api/elections/index.html?lang=hi&theme=dark",
      "webview_title": "चुनाव 2026"
    },
    {
      "id": "noticeboard",
      "type": "webview_banner",
      "visible": true,
      "order": 1,
      ...
    }
  ],
  "ttl": 300
}
```

No app release needed. As soon as the backend returns this, the Elections card appears at the top.

---

## 9. Caching

### Server-side headers

```
Cache-Control: public, max-age=<ttl>
```

Set `max-age` to the same value as the `ttl` field in the JSON body. This lets CDNs and the HTTP client cache the response appropriately.

### Client-side behaviour

The Flutter app will:
1. Fetch `/api/home/sections?lang=…&theme=…` on home page open.
2. Cache the response locally for `ttl` seconds.
3. Within the TTL window, use the cached response without re-fetching.
4. After TTL expires, re-fetch in the background; continue showing old sections until new response arrives (no loading spinner between refreshes).
5. Persist the last successful response to survive app cold starts — see §10.

### Separate cache per `lang` + `theme`

The client caches `(lang, theme)` pairs separately, since each combination returns different URLs and translated strings.

---

## 10. Error Handling & Fallback

| Scenario                    | App behaviour                                                                 |
| --------------------------- | ----------------------------------------------------------------------------- |
| API returns `200` with data | Render sections normally                                                      |
| API returns empty `sections`| Hide the entire section area below local news (no card, no padding)           |
| API returns `4xx` / `5xx`   | Use last persisted cached response, if available                              |
| Network unavailable         | Use last persisted cached response, if available                              |
| No cache at all             | Hide section area silently — no error UI shown to user                        |
| Unknown `type` field        | Skip that section silently; render all other sections                         |
| Missing required field      | Skip that section silently; render all other sections                         |

The golden rule: **section failures must never break the rest of the home page.**

---

## 11. Frontend Behaviour (Flutter side)

This section documents what the Flutter app will do, for backend reference.

1. On home page `initState`, fire `GET /api/home/sections?lang=$lang&theme=$theme`.
2. Show a subtle loading shimmer in the section area while waiting.
3. On success: parse JSON, filter `visible == true`, iterate in order, render each known `type`.
4. Cache the response (in-memory + `SharedPreferences`) with the `ttl` from the response.
5. On next open within TTL: render from cache, fire a background refresh.
6. Unknown `type` → silently skip.
7. Any section with missing fields (`banner_image_url`, `webview_url`, etc.) → silently skip.
8. Tapping a `webview_banner` card → open `WebViewPage(title: webview_title, url: webview_url)`.

---

## 12. What the Backend Can Change Without an App Release

Once the app is on this API, the backend can do ALL of the following with zero app changes:

| Action                                         | How                                            |
| ---------------------------------------------- | ---------------------------------------------- |
| Add a new section                              | Add a new object to the `sections` array       |
| Remove a section permanently                   | Remove it from the array                       |
| Temporarily hide a section                     | Set `"visible": false`                         |
| Reorder sections                               | Change the `order` values                      |
| Rename a section                               | Update `title` and `webview_title`             |
| Change the section icon                        | Update `icon` to any value in §7               |
| Change the banner image                        | Point `banner_image_url` to a different URL    |
| Change what page opens on tap                  | Point `webview_url` to a different URL         |
| Point a section to an entirely different domain| Just change the URL strings                    |
| Make sections refresh faster or slower         | Lower or raise the `ttl` value                 |
| Add future section types (elections, polls…)   | Add them with a new `type` string — old app versions skip, new versions render |

---

## 13. Migration from Current Hardcoded Setup

The app currently has Noticeboard and Games hardcoded. The migration plan:

### Phase 1 — Backend implements the endpoint

Implement `GET /api/home/sections` returning the two existing sections (Noticeboard and Games) in JSON, functionally identical to what is hardcoded today.

Use these exact `id` values:
- `"noticeboard"` for the Noticeboard section
- `"games"` for the Games / Quiz section

### Phase 2 — Frontend switches over

The Flutter app removes its hardcoded `_buildBannerSection` calls and instead fetches + renders from the API. After this app version goes live, the backend has full control.

### Phase 3 — Hardcoded code removed

Once the new app version has sufficient adoption (old version users see the hardcoded sections, new version users see the API-driven sections), the hardcoded code can be fully deleted.

---

## HTTP Response Summary

| Status | Meaning                      | App action                        |
| ------ | ---------------------------- | --------------------------------- |
| `200`  | Success                      | Parse and render                  |
| `304`  | Not modified (ETag/cache hit)| Keep current cached sections      |
| `4xx`  | Client error                 | Fall back to persisted cache      |
| `5xx`  | Server error                 | Fall back to persisted cache      |

---

*This document is the single source of truth for the Home Sections API contract. Any changes to the schema should be reflected here before implementation.*

# Backend Transliteration Support — API Spec

**For:** Backend Team  
**From:** Mobile App Team  
**Date:** February 2026  
**Priority:** Medium  

---

## Background

The Rate My Mantri app currently supports 10 Indian languages:

| Code | Language | Script |
|------|----------|--------|
| `hi` | Hindi    | Devanagari |
| `mr` | Marathi  | Devanagari |
| `ta` | Tamil    | Tamil |
| `te` | Telugu   | Telugu |
| `kn` | Kannada  | Kannada |
| `ml` | Malayalam| Malayalam |
| `bn` | Bengali  | Bengali |
| `gu` | Gujarati | Gujarati |
| `pa` | Punjabi  | Gurmukhi |
| `en` | English  | Latin (default) |

Right now the app does **client-side transliteration** of all name/party/constituency/state data using the `inditrans` library. This works but has limits — the library is general-purpose and does not know that "BJP" should render as "बीजेपी" rather than a raw letter-by-letter conversion.

---

## What We Need

Add an **optional `lang` query parameter** to the relevant API endpoints.

When `lang` is provided, the response should return all **text identity fields** (name, party, state, constituency, etc.) transliterated into the requested script.

> **Transliteration ≠ Translation.**  
> "BJP" does NOT become "भारतीय जनता पार्टी" (that is translation).  
> "BJP" BECOMES "बीजेपी" (phonetic script conversion — same sounds, different script).  
> "Yogi Adityanath" BECOMES "योगी आदित्यनाथ".  
> "Gorakhpur" BECOMES "गोरखपुर".

---

## Parameter Specification

```
?lang=hi
```

- **Type:** `string`
- **Optional:** Yes — if omitted, response is unchanged (current English behaviour)
- **Valid values:** `hi | mr | ta | te | kn | ml | bn | gu | pa`
- **Invalid value behaviour:** Ignore silently, return English (do not error)

---

## Affected Endpoints & Fields

### 1. `GET /v2/representatives/search`

**Fields to transliterate:**

| Field | Example (en) | Example (hi) |
|-------|-------------|--------------|
| `name` | `"YOGI ADITYANATH"` | `"योगी आदित्यनाथ"` |
| `party` | `"BJP"` | `"बीजेपी"` |
| `state` | `"UTTAR PRADESH"` | `"उत्तर प्रदेश"` |
| `constituency` | `"GORAKHPUR"` | `"गोरखपुर"` |
| `self_profession` | `"Politician"` | `"पॉलिटिशियन"` |
| `spouse_profession` | `"Teacher"` | `"टीचर"` |

**Fields NOT to transliterate:**  
`id`, `candidate_id`, `office_type`, `image_url`, `assets`, `liabilities`, `education`, `total_cases`, `ipc_cases_count`, `bns_cases_count`

---

### 2. `GET /v2/representatives/:id`

**Fields to transliterate:**

| Field | Example (en) | Example (hi) |
|-------|-------------|--------------|
| `name` | `"YOGI ADITYANATH"` | `"योगी आदित्यनाथ"` |
| `party` | `"BJP"` | `"बीजेपी"` |
| `state` | `"UTTAR PRADESH"` | `"उत्तर प्रदेश"` |
| `constituency` | `"GORAKHPUR"` | `"गोरखपुर"` |
| `self_profession` | `"Politician"` | `"पॉलिटिशियन"` |
| `spouse_profession` | `"Teacher"` | `"टीचर"` |
| `education` | `"Graduate"` | `"ग्रेजुएट"` |
| `ipc_cases[]` (each string) | `"Charges under section..."` | transliterated |
| `bns_cases[]` (each string) | `"Charges under section..."` | transliterated |

**Fields NOT to transliterate:**  
`id`, `candidate_id`, `office_type`, `term`, `image_url`, `assets`, `liabilities`, `self_itr` (keys/values are years/numbers), `spouse_itr`, `total_cases`

---

### 3. `GET /v2/my-representatives`

**Used by:** Home page rep cards and constituency map  
**Fields to transliterate:** `name`, `party`, `state`, `constituency`

The response has a nested structure with keys `mla`, `lokSabha`, `rajyaSabha`, `vidhanParishad`. Transliterate the same fields in each nested representative object.

**Fields NOT to transliterate:**  
`id`, `candidate_id`, `office_type`, `image_url`, `assets`, `liabilities`, `total_cases`

> **Note:** This endpoint was missing from the original spec — this is why the home page rep cards still show English names while the representative detail page works correctly.

---

### 4. `GET /v2/representatives/top-assets`

**Fields to transliterate:** `name`, `party`, `state`, `constituency`  
**Fields NOT to transliterate:** `id`, `candidate_id`, `office_type`, `assets`, `liabilities`, `net_worth`

---

### 4. `GET /v2/representatives/most-cases`

**Fields to transliterate:** `name`, `party`, `state`, `constituency`  
**Fields NOT to transliterate:** `id`, `candidate_id`, `office_type`, `total_cases`, `ipc_cases` (count), `bns_cases` (count)

---

### 5. `GET /v2/metadata/parties`

**Fields to transliterate:** `party`

**Example response with `?lang=hi`:**
```json
{
  "success": true,
  "count": 150,
  "data": [
    { "party": "बीजेपी", "count": 1500 },
    { "party": "आईएनसी", "count": 800 },
    { "party": "आआप", "count": 95 }
  ]
}
```

---

### 6. `GET /api/ratings/statistics/:representativeId`

Within the nested `statistics.representative` object:

**Fields to transliterate:** `name`, `party`, `state`, `constituency`

```json
"representative": {
  "name": "योगी आदित्यनाथ",
  "officeType": "LOK_SABHA",
  "state": "उत्तर प्रदेश",
  "constituency": "गोरखपुर",
  "party": "बीजेपी"
}
```

Note: `officeType` is **not** transliterated — the app maps it locally (`LOK_SABHA` → "सांसद (लोक सभा)").

---

### 7. `GET /api/ratings/user/me`

**Fields to transliterate:** `representativeName`, `party`, `state`, `constituency`  
**Fields NOT to transliterate:** `id`, `representativeId`, `representativeImage`, `officeType`, `ratingType`, numeric fields, dates

---

## Endpoints That Do NOT Need `lang`

| Endpoint | Reason |
|----------|--------|
| `POST /api/ratings` | Input only — no text fields |
| `PUT /api/ratings/:id` | Input only |
| `DELETE /api/ratings/:id` | No text in response |
| `GET /api/ratings/representative/:id` | `userName` is user-entered — never transliterate user data. `reviewText` likewise |
| `GET /v2/metadata/states` | Returns a flat string array — add transliteration here too if easy, otherwise skip |
| `GET /v2/representatives/stats` | Pure numeric stats |

---

## Implementation Notes

### Suggested Approach

1. Accept `?lang=xx` on the listed routes.
2. After fetching from DB (which stores English/Latin text), run transliteration on the text fields before sending the response.
3. For transliteration, use a Node.js/Python library that maps Latin → target script. Suggested libraries:
   - Node.js: [`lipi-toolkit`](https://www.npmjs.com/package/lipi-toolkit) or [`sanscript.js`](https://github.com/sanskrit/sanscript.js)
   - Python: [`indic-transliteration`](https://pypi.org/project/indic-transliteration/)
4. Cache transliterated responses separately per `lang` value (e.g., cache key = `search:<query>:hi`).

### Caching Consideration

The current cache keys are per-query. With `lang`, they should be per-query-per-language:

```
// Before
cache_key = `search:${ q }:${ limit }:${ offset }`

// After
cache_key = `search:${ q }:${ limit }:${ offset }:${ lang ?? 'en' }`
```

### Do NOT Transliterate

- `office_type` enum values — the app handles these locally
- `ratingType` strings — internal use
- URLs, IDs, numeric fields
- User-generated content (`reviewText`, `userName`) — these are typed by users and must be preserved as-is

---

## What the App Will Change (Our Side)

Once the backend supports `lang`, the app will:
1. Pass `?lang=<current_language>` on all representative/ratings API calls
2. **Remove client-side transliteration** for `name`, `party`, `constituency`, `state` fields — the server will already return the correct script
3. Keep client-side transliteration only for UI strings (labels, buttons, etc.) which are handled by `AppTranslations`

This will improve accuracy (especially for party abbreviations) and reduce CPU usage on the client.

---

## Summary Table

| Route | `lang` needed | Fields affected |
|-------|:-------------:|-----------------|
| `GET /v2/representatives/search` | ✅ | name, party, state, constituency, self_profession, spouse_profession |
| `GET /v2/representatives/:id` | ✅ | name, party, state, constituency, self_profession, spouse_profession, education, ipc_cases[], bns_cases[] |
| `GET /v2/my-representatives` | ✅ | name, party, state, constituency (in each nested rep object) |
| `GET /v2/representatives/top-assets` | ✅ | name, party, state, constituency |
| `GET /v2/representatives/most-cases` | ✅ | name, party, state, constituency |
| `GET /v2/metadata/parties` | ✅ | party |
| `GET /api/ratings/statistics/:id` | ✅ | representative.name, .party, .state, .constituency |
| `GET /api/ratings/user/me` | ✅ | representativeName, party, state, constituency |
| `GET /v2/metadata/states` | 🟡 optional | array of state strings |
| `POST /api/ratings` | ❌ | — |
| `PUT /api/ratings/:id` | ❌ | — |
| `DELETE /api/ratings/:id` | ❌ | — |
| `GET /api/ratings/representative/:id` | ❌ | user content — never transliterate |
| `GET /v2/representatives/stats` | ❌ | numeric only |

---

*Questions? Contact the mobile app team.*

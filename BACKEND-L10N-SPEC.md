# Backend Localisation Spec — Representative Detail API

> **Date:** 2026-02-28  
> **Raised by:** Frontend Team  
> **Priority:** Medium  
> **Affects:** `GET /v2/representatives/:id` (and related listing endpoints)

---

## Problem

The app supports **10 Indian languages** (English, Hindi, Marathi, Tamil, Telugu, Kannada, Malayalam, Bengali, Gujarati, Punjabi).

The frontend currently displays the following data fields from the backend on the **Representative Detail Page**:

| Field | Example value (from API) |
|---|---|
| `name` | `Rahul Gandhi` |
| `party` | `Indian National Congress` |
| `state` | `Kerala` |
| `constituency` | `Wayanad` |
| `office_type` | `LOK_SABHA` |
| `self_profession` | `Agriculturist` |
| `spouse_profession` | `Homemaker` |
| `education` | `M.Phil in Development Economics` |
| `ipc_cases[]` | `"Section 153A IPC - Promoting enmity..."` |
| `bns_cases[]` | `"Section 196 BNS - Promoting enmity..."` |

**All of these fields arrive in English only**, regardless of the app's selected language.

Since these are proper nouns and domain-specific strings (party names, state names, legal section descriptions), **frontend transliteration (phonetic script conversion) produces poor quality results**:

- `"BJP"` → phonetically in Devanagari instead of the correct native name `"भाजपा"`
- `"Kerala"` → `"केरला"` instead of `"केरल"`
- `"Agriculturist"` → garbled phonetic output in Tamil/Telugu/Kannada scripts
- Legal case descriptions → completely unreadable after phonetic conversion

> **Note:** The frontend is **already sending the `?lang=` parameter** on this API call. The backend is currently ignoring it.
>
> Current call from Flutter:
> ```
> GET /v2/representatives/{id}?lang=hi
> GET /v2/representatives/{id}?lang=ta
> GET /v2/representatives/{id}?lang=en
> ... etc.
> ```

---

## Requested Change

### 1. Read and honour the `?lang` query parameter

When `?lang=<code>` is present and not `en`, return **localised versions** of the text fields in the response.

**Supported language codes:**

| Code | Language   |
|------|------------|
| `en` | English (default, no change needed) |
| `hi` | Hindi |
| `mr` | Marathi |
| `ta` | Tamil |
| `te` | Telugu |
| `kn` | Kannada |
| `ml` | Malayalam |
| `bn` | Bengali |
| `gu` | Gujarati |
| `pa` | Punjabi |

If `?lang` is absent or unrecognised, default to English (existing behaviour).

---

### 2. Fields that MUST be localised

#### High priority (most visible to user)

| Field | Notes |
|---|---|
| `state` | Known finite set of 28 states + 8 UTs. Maintain a lookup table. |
| `party` | Known finite set of registered parties (ECI list). Maintain a lookup table. |
| `constituency` | Proper noun — transliterate using standard ECI/Delimitation Commission spellings OR pass through a curated lookup. |
| `office_type` | Enum values: `LOK_SABHA`, `RAJYA_SABHA`, `STATE_ASSEMBLY`, `VIDHAN_PARISHAD`. Return a localised label string alongside (or instead of) the enum. |

#### Medium priority

| Field | Notes |
|---|---|
| `name` | Official ECI transliterations exist for most politicians. Attempt lookup; fall back to English if not available. |
| `self_profession` / `spouse_profession` | Affidavit data — may be free text. Attempt translation via a standard occupation lookup table for common values. |
| `education` | Affidavit data — free text. Best effort; fall back to English if no translation exists. |

#### Lower priority (but still noticeable)

| Field | Notes |
|---|---|
| `ipc_cases[]` / `bns_cases[]` | Legal section names are standardised. A lookup table of common IPC/BNS sections in Indian languages would work well here. Free-text descriptions can be left in English if translation is not feasible. |

---

### 3. Suggested Response Shape

No breaking changes needed. The frontend will use the `lang`-aware version transparently.

**Option A — Replace in-place (recommended for minimal frontend change)**

Return the same JSON structure, but with the localised string in the field itself:

```json
// GET /v2/representatives/123?lang=hi
{
  "success": true,
  "data": {
    "id": 123,
    "name": "राहुल गांधी",
    "party": "भारतीय राष्ट्रीय कांग्रेस",
    "state": "केरल",
    "constituency": "वायनाड",
    "office_type": "LOK_SABHA",
    "self_profession": "कृषक",
    "education": "विकास अर्थशास्त्र में M.Phil",
    "ipc_cases": ["धारा 153A IPC - ..."],
    ...
  }
}
```

**Option B — Add parallel `_local` fields (zero frontend breaking change, slightly larger payload)**

```json
{
  "success": true,
  "data": {
    "name": "Rahul Gandhi",
    "name_local": "राहुल गांधी",
    "party": "Indian National Congress",
    "party_local": "भारतीय राष्ट्रीय कांग्रेस",
    "state": "Kerala",
    "state_local": "केरल",
    ...
  }
}
```

> **Frontend preference: Option A.** The cache key is already scoped per language (`rep_detail_{id}_{lang}`), so there is no conflict. This keeps the payload lean and avoids any model changes on our side.

---

### 4. Fallback Behaviour

- If a localised value is **not available** for a given field, return the **English value as-is**. Do not return `null` or an empty string.
- If `?lang=en` or no `?lang` param is sent, return all English values (existing behaviour — no change).

---

### 5. Caching Tip for Backend

Store translated records **per language** to avoid re-translating on every request:

```
representatives_detail:{id}:en  → English version
representatives_detail:{id}:hi  → Hindi version
representatives_detail:{id}:ta  → Tamil version
...
```

Cache can be warmed lazily (on first request per language) or eagerly during data ingestion.

---

### 6. Endpoints This Applies To

The same `?lang` parameter should be honoured consistently across all representative endpoints:

| Endpoint | Current `?lang` sent by frontend? |
|---|---|
| `GET /v2/representatives/:id` | ✅ Yes (already sent, not handled) |
| `GET /v2/representatives/search?q=...` | ✅ Yes (already sent, not handled) |
| `GET /v2/my-representatives?location=...` | ✅ Yes (already sent, not handled) |

The search and listing endpoints have lower priority since they only show `name`, `party`, `state`, and `constituency` — but it would be great to handle them all together.

---

## Summary / TL;DR

The frontend already sends `?lang=hi` (or any other language code) on every representative API call. The backend currently ignores it and returns English-only data. This causes the frontend to attempt phonetic transliteration using a library, which produces low-quality, sometimes unreadable output for proper nouns and legal strings.

**The fix:** Read `?lang`, and return localised text for `state`, `party`, `constituency`, `office_type`, and ideally `name` and profession fields. Fall back to English for any value that doesn't have a translation. No changes needed on the frontend side — it will pick up the localised data automatically.

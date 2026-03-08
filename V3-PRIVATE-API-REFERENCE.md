# V3 Private API - Complete Reference

All V3 routes require JWT authentication. This is the **single API surface** your Flutter app should use for all data fetching.

## Base URL
```
https://ratemymantri.sallytion.qzz.io/v3
```

## Authentication

Every request must include:
```
Authorization: Bearer <accessToken>
```

### Getting a token
```http
POST /auth/google
Content-Type: application/json

{ "idToken": "<Firebase/Google ID token>" }
```
Response:
```json
{
  "success": true,
  "user": { "id", "email", "name", "profileImage", "isVerified" },
  "tokens": { "accessToken", "refreshToken" }
}
```

### Refreshing a token
```http
POST /auth/refresh
Content-Type: application/json

{ "refreshToken": "<token>" }
```
Response:
```json
{ "success": true, "tokens": { "accessToken", "refreshToken" } }
```

### Auth errors
| HTTP | Body | Meaning |
|------|------|---------|
| 401 | `{"error":"Authorization header missing"}` | No `Authorization` header sent |
| 401 | `{"error":"Invalid authorization format"}` | Header doesn't start with `Bearer ` |
| 401 | `{"error":"Token expired"}` | Access token expired — call `/auth/refresh` |
| 401 | `{"error":"Invalid token"}` | Token is malformed or tampered |

---

## Multilingual Support

All endpoints accept an optional `lang` query parameter.

**Supported values:** `hi` (Hindi), `mr` (Marathi), `ta` (Tamil), `te` (Telugu), `kn` (Kannada), `ml` (Malayalam), `bn` (Bengali), `gu` (Gujarati), `pa` (Punjabi)

If omitted or set to `en`, responses are in English.

**What gets translated:**
- **Transliterated** (phonetic script conversion): `name`, `full_name`, `state`, `constituency`
- **Translated** (meaning-based): `education`, `self_profession`, `spouse_profession`, criminal case descriptions
- **Mapped**: `party` names (dictionary lookup)
- **Banner/HTML**: Full HTML auto-translation via Google Translate
- **Home section titles**: Batch translated

---

## Endpoints At a Glance

| # | Method | Endpoint | Description | Cache |
|---|--------|----------|-------------|-------|
| 1 | GET | `/representatives/search` | V2 search with advanced filters | 5 min |
| 2 | GET | `/representatives/:id` | V2 detailed representative profile | 5 min |
| 3 | GET | `/representatives/stats` | Overall DB statistics | 10 min |
| 4 | GET | `/representatives/top-assets` | Richest representatives | 10 min |
| 5 | GET | `/representatives/most-cases` | Most criminal cases | 10 min |
| 6 | GET | `/metadata/states` | All unique states | 1 hour |
| 7 | GET | `/metadata/parties` | All parties with counts | 1 hour |
| 8 | GET | `/my-representatives` | Geo-based lookup | 5 min |
| 9 | GET | `/legacy/representatives` | V1 search (old schema) | 1 min |
| 10 | GET | `/legacy/representatives/:personId` | V1 profile (old schema) | 2 min |
| 11 | GET | `/ratings/representative/:id` | Ratings list for a rep | 1 min |
| 12 | GET | `/ratings/statistics/:id` | Rating stats for a rep | 5 min |
| 13 | GET | `/banner.png` | Banner image (PNG) | 1 hour |
| 14 | GET | `/banner/game.html` | Quiz game (HTML) | no-store |
| 15 | GET | `/banner/noticeboard.html` | Noticeboard (HTML) | no-store |
| 16 | GET | `/banner/:baseName` | Dynamic banner PNG | 1 hour |
| 17 | GET | `/home/sections` | Home page sections | 5 min |

---

## 1. Search Representatives (V2)

```http
GET /v3/representatives/search?q=modi&state=Uttar Pradesh&limit=10&lang=hi
```

| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `q` | string | — | Search name, state, constituency, party |
| `state` | string | — | Filter by state |
| `constituency` | string | — | Filter by constituency |
| `party` | string | — | Filter by party |
| `officeType` | string | — | `LOK_SABHA`, `RAJYA_SABHA`, `STATE_ASSEMBLY`, `VIDHAN_PARISHAD` |
| `hasAssets` | boolean | — | Only those with asset data |
| `hasCases` | boolean | — | Only those with criminal cases |
| `limit` | int | 50 | Max 100 |
| `offset` | int | 0 | Pagination |
| `lang` | string | en | Transliterate response |

**Response:**
```json
{
  "success": true,
  "count": 2,
  "limit": 10,
  "offset": 0,
  "results": [
    {
      "id": 15193,
      "name": "नरेंद्र मोदी",
      "state": "उत्तर प्रदेश",
      "constituency": "वाराणसी",
      "party": "भारतीय जनता पार्टी",
      "office_type": "LOK_SABHA",
      "image_url": "https://...",
      "total_assets": 30000000,
      "criminal_cases_count": 0,
      "self_profession": "...",
      "spouse_profession": "..."
    }
  ]
}
```

---

## 2. Representative Detail (V2)

```http
GET /v3/representatives/15193?lang=hi
```

Returns full profile including ITR data, criminal cases (IPC/BNS sections), education, profession.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 15193,
    "name": "नरेंद्र मोदी",
    "state": "उत्तर प्रदेश",
    "constituency": "वाराणसी",
    "party": "भारतीय जनता पार्टी",
    "office_type": "LOK_SABHA",
    "image_url": "...",
    "gender": "male",
    "education": "...",
    "self_profession": "...",
    "spouse_profession": "...",
    "total_assets": 30000000,
    "total_liabilities": 0,
    "movable_assets": 10000000,
    "immovable_assets": 20000000,
    "itr_data": [ { "year": "2022-23", "income": 1500000 } ],
    "criminal_cases_count": 0,
    "ipc_cases": [],
    "bns_cases": []
  }
}
```

---

## 3. Overall Statistics

```http
GET /v3/representatives/stats
```

No query params. Returns aggregate counts.

---

## 4. Top Representatives by Assets

```http
GET /v3/representatives/top-assets?limit=10&lang=hi
```

| Param | Type | Default | Max |
|-------|------|---------|-----|
| `limit` | int | 10 | 50 |
| `lang` | string | en | — |

---

## 5. Representatives with Most Criminal Cases

```http
GET /v3/representatives/most-cases?limit=10&lang=hi
```

Same params as top-assets.

---

## 6. All States

```http
GET /v3/metadata/states?lang=hi
```

**Response:**
```json
{
  "success": true,
  "count": 36,
  "data": ["उत्तर प्रदेश", "महाराष्ट्र", "..."]
}
```

---

## 7. All Parties

```http
GET /v3/metadata/parties?lang=hi
```

**Response:**
```json
{
  "success": true,
  "count": 45,
  "data": [
    { "party": "भारतीय जनता पार्टी", "count": 303 },
    { "party": "भारतीय राष्ट्रीय कांग्रेस", "count": 99 }
  ]
}
```

---

## 8. My Representatives (Geo-based)

```http
GET /v3/my-representatives?location=Bundi&lang=hi
```

| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `location` | string | Yes | City/area name (e.g. "Mumbai", "Bundi", "Varanasi") |
| `lang` | string | No | Transliterate response |

**Response:**
```json
{
  "success": true,
  "location": {
    "query": "Bundi",
    "resolved": {
      "name": "Bundi",
      "latitude": 25.44,
      "longitude": 75.63,
      "state": "Rajasthan",
      "district": "Bundi",
      "subdistrict": null
    },
    "lokSabhaConstituency": {
      "name": "Kota",
      "state": "Rajasthan",
      "matchType": "point-in-polygon"
    }
  },
  "representatives": {
    "mla": [ { "id": 123, "name": "...", ... } ],
    "lokSabha": { "id": 456, "name": "...", ... },
    "rajyaSabha": [ { ... }, { ... } ],
    "vidhanParishad": []
  },
  "summary": {
    "totalRepresentatives": 5,
    "mlaCount": 1,
    "hasLokSabhaMember": true,
    "rajyaSabhaCount": 3,
    "vidhanParishadCount": 0
  }
}
```

---

## 9. Legacy Search (V1 Schema)

```http
GET /v3/legacy/representatives?q=modi&limit=10&lang=hi
```

Uses the old `persons`/`person_roles` database tables. Useful if you need V1-style data.

| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `q` | string | — | Search across name, state, constituency, party |
| `state` | string | — | Filter by state |
| `constituency` | string | — | Filter by constituency |
| `party` | string | — | Filter by party |
| `office` | string | — | Filter by office title (e.g. "MLA", "MP - Lok Sabha") |
| `current` | string | — | `"true"` = current reps only, `"false"` = past only |
| `limit` | int | 20 | No hard max |
| `offset` | int | 0 | Pagination |
| `lang` | string | en | Transliterate response |

**Response:**
```json
{
  "success": true,
  "count": 2,
  "results": [
    {
      "person_id": "487a269b-2b3c-4bac-9b05-195881b1e219",
      "full_name": "नरेंद्र मोदी",
      "gender": "male",
      "education": "बी.ए., दिल्ली विश्वविद्यालय...",
      "image_url": "https://...",
      "office": "MP - Lok Sabha",
      "term_number": null,
      "start_date": "2024-06-09T00:00:00.000Z",
      "end_date": null,
      "is_current": true,
      "constituency": "वाराणसी",
      "state": "उत्तर प्रदेश",
      "party": "Bharatiya Janata Party"
    }
  ]
}
```

> Note: `person_id` is a UUID in the V1 schema.

---

## 10. Legacy Profile (V1 Schema)

```http
GET /v3/legacy/representatives/487a269b-2b3c-4bac-9b05-195881b1e219?lang=hi
```

| Param | Type | Notes |
|-------|------|-------|
| `lang` | string | Transliterate name, state, constituency; translate education |

**Response:**
```json
{
  "success": true,
  "data": {
    "person": {
      "id": "487a269b-...",
      "full_name": "नरेंद्र मोदी",
      "gender": "male",
      "education": "बी.ए., दिल्ली विश्वविद्यालय, दिल्ली, 1978; एमए, गुजरात विश्वविद्यालय, अहमदाबाद, 1983",
      "image_url": "https://...",
      "email": null,
      "contact": null
    },
    "current_role": {
      "office": "MP - Lok Sabha",
      "term_number": null,
      "start_date": "2024-06-09T00:00:00.000Z",
      "end_date": null,
      "is_current": true,
      "constituency": "वाराणसी",
      "state": "उत्तर प्रदेश",
      "party": "Bharatiya Janata Party",
      "note": "..."
    },
    "statistics": {
      "attendance_percent": null,
      "attendance_state_avg": null,
      "questions_asked": null,
      "questions_state_avg": null,
      "debates_participated": null,
      "debates_state_avg": null
    }
  }
}
```

> Note: Pass the UUID `person_id` from the legacy search results (not the integer `id` from V2).

---

## 11. Ratings for a Representative

```http
GET /v3/ratings/representative/15193?limit=10&offset=0&sortBy=created_at&sortOrder=DESC&lang=hi
```

| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `limit` | int | 50 | Max 100 |
| `offset` | int | 0 | Pagination |
| `sortBy` | string | `created_at` | `created_at`, `overall_score`, `updated_at` |
| `sortOrder` | string | `DESC` | `ASC` or `DESC` |
| `lang` | string | en | Transliterate representative metadata |

**Response:**
```json
{
  "success": true,
  "representativeId": 15193,
  "representative": {
    "name": "नरेंद्र मोदी",
    "officeType": "LOK_SABHA",
    "state": "उत्तर प्रदेश",
    "constituency": "वाराणसी",
    "party": "भारतीय जनता पार्टी"
  },
  "statistics": {
    "totalRatings": 5,
    "avgOverallScore": 3.8,
    "overallStars": 4
  },
  "ratings": [
    {
      "id": 42,
      "ratingType": "verified_named",
      "question1Stars": 4,
      "question2Stars": 3,
      "question3Stars": 4,
      "overallScore": 3.67,
      "reviewText": "Good work in constituency",
      "userName": "John Doe",
      "userProfileImage": "https://...",
      "createdAt": "2026-03-01T10:00:00.000Z",
      "updatedAt": "2026-03-01T10:00:00.000Z"
    }
  ],
  "pagination": {
    "limit": 10,
    "offset": 0,
    "count": 5
  }
}
```

> `representative` is `null` if no statistics exist yet.

---

## 12. Rating Statistics

```http
GET /v3/ratings/statistics/15193?lang=hi
```

| Param | Type | Notes |
|-------|------|-------|
| `lang` | string | Transliterate representative metadata |

**Response:**
```json
{
  "success": true,
  "representativeId": 15193,
  "statistics": {
    "totalRatings": 5,
    "verifiedNamedCount": 3,
    "verifiedAnonymousCount": 1,
    "unverifiedCount": 1,
    "avgOverallScore": 3.8,
    "avgQ1Stars": 4.0,
    "avgQ2Stars": 3.5,
    "avgQ3Stars": 3.9,
    "overallStars": 4,
    "latestRatingDate": "2026-03-01T10:00:00.000Z",
    "representative": {
      "name": "नरेंद्र मोदी",
      "officeType": "LOK_SABHA",
      "state": "उत्तर प्रदेश",
      "constituency": "वाराणसी",
      "party": "भारतीय जनता पार्टी"
    }
  }
}
```

---

## 13-16. Banner Routes

### Banner PNG
```http
GET /v3/banner.png?theme=light|dark
```
Returns PNG image. `theme` defaults to `light`.

### Game Page
```http
GET /v3/banner/game.html?lang=hi&theme=dark
```
Returns fully translated HTML quiz game. Load in a WebView.

### Noticeboard Page
```http
GET /v3/banner/noticeboard.html?lang=ta&theme=dark
```
Returns fully translated HTML noticeboard. Load in a WebView.

### Dynamic Banner PNG
```http
GET /v3/banner/game_banner?theme=dark&lang=hi
```
Returns locale- and theme-specific PNG banner image.

**Fallback chain:**
1. `game_banner_dark_hi.png`
2. `game_banner_dark_en.png`
3. `game_banner_dark.png`
4. `game_banner.png`

---

## 17. Home Sections

```http
GET /v3/home/sections?lang=hi&theme=dark
```

| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `lang` | string | en | Translate section titles |
| `theme` | string | light | `light` or `dark` — affects banner/webview URLs |

**Response:**
```json
{
  "sections": [
    {
      "id": 1,
      "type": "webview_banner",
      "visible": true,
      "order": 1,
      "title": "प्रश्नोत्तरी खेल",
      "icon": "games",
      "banner_image_url": "https://ratemymantri.sallytion.qzz.io/api/banner/game_banner?lang=hi&theme=dark",
      "webview_url": "https://ratemymantri.sallytion.qzz.io/api/banner/game.html?lang=hi&theme=dark",
      "webview_title": "प्रश्नोत्तरी खेलें"
    }
  ],
  "ttl": 300
}
```

---

## Flutter Integration Checklist

### Auth setup
- [ ] Store `accessToken` and `refreshToken` in `flutter_secure_storage`
- [ ] Add auth interceptor to your HTTP client (Dio recommended):
  ```dart
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      options.headers['Authorization'] = 'Bearer $accessToken';
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        // Refresh token and retry
        final newTokens = await refreshToken();
        error.requestOptions.headers['Authorization'] = 'Bearer ${newTokens.accessToken}';
        final response = await dio.fetch(error.requestOptions);
        handler.resolve(response);
      } else {
        handler.next(error);
      }
    },
  ));
  ```

### Switching from public to V3
- [ ] Replace `/v2/representatives/search` with `/v3/representatives/search`
- [ ] Replace `/v2/representatives/:id` with `/v3/representatives/:id`
- [ ] Replace `/api/ratings/statistics/:id` with `/v3/ratings/statistics/:id`
- [ ] Replace `/api/ratings/representative/:id` with `/v3/ratings/representative/:id`
- [ ] Replace `/api/home/sections` with `/v3/home/sections`
- [ ] Replace `/api/banner/*` with `/v3/banner/*`
- [ ] Ensure `lang` param is passed on every request based on user's locale

### Testing
- [ ] Verify 401 returned when no token is sent
- [ ] Verify token refresh flow works when access token expires
- [ ] Test with `lang=hi` and confirm Hindi text renders correctly
- [ ] Test with `lang=ta` (Tamil) — different script family
- [ ] Verify old public routes still work (backwards compatibility)

---

## Mapping: Old Public Routes → V3 Private

| Old Public Route | New V3 Private Route |
|---|---|
| `GET /public/representatives` | `GET /v3/legacy/representatives` |
| `GET /public/representatives/:personId` | `GET /v3/legacy/representatives/:personId` |
| `GET /v2/representatives/search` | `GET /v3/representatives/search` |
| `GET /v2/representatives/:id` | `GET /v3/representatives/:id` |
| `GET /v2/representatives/stats` | `GET /v3/representatives/stats` |
| `GET /v2/representatives/top-assets` | `GET /v3/representatives/top-assets` |
| `GET /v2/representatives/most-cases` | `GET /v3/representatives/most-cases` |
| `GET /v2/metadata/states` | `GET /v3/metadata/states` |
| `GET /v2/metadata/parties` | `GET /v3/metadata/parties` |
| `GET /v2/my-representatives` | `GET /v3/my-representatives` |
| `GET /api/ratings/representative/:id` | `GET /v3/ratings/representative/:id` |
| `GET /api/ratings/statistics/:id` | `GET /v3/ratings/statistics/:id` |
| `GET /api/banner.png` | `GET /v3/banner.png` |
| `GET /api/banner/game.html` | `GET /v3/banner/game.html` |
| `GET /api/banner/noticeboard.html` | `GET /v3/banner/noticeboard.html` |
| `GET /api/banner/:baseName` | `GET /v3/banner/:baseName` |
| `GET /api/home/sections` | `GET /v3/home/sections` |

All old public routes remain fully functional and unchanged.

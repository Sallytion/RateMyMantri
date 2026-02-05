# Representatives V2 API - Quick Reference

## Base URL
```
https://ratemymantri.sallytion.qzz.io/v2
```

---

## Endpoints Summary

| Method | Endpoint | Description | Cache |
|--------|----------|-------------|-------|
| GET | `/representatives/search` | Search with filters | 5 min |
| GET | `/representatives/:id` | Get detailed info | 5 min |
| GET | `/representatives/stats` | Overall statistics | 10 min |
| GET | `/representatives/top-assets` | Richest representatives | 10 min |
| GET | `/representatives/most-cases` | Most criminal cases | 10 min |
| GET | `/metadata/states` | All unique states | 1 hour |
| GET | `/metadata/parties` | All parties with counts | 1 hour |

---

## 1. Search Representatives

```http
GET /v2/representatives/search
```

### Query Parameters

```typescript
{
  q?: string,              // General search
  state?: string,          // Filter by state
  constituency?: string,   // Filter by constituency
  party?: string,          // Filter by party
  officeType?: 'LOK_SABHA' | 'RAJYA_SABHA' | 'STATE_ASSEMBLY' | 'VIDHAN_PARISHAD',
  hasAssets?: boolean,     // Has asset data
  hasCases?: boolean,      // Has criminal cases
  limit?: number,          // Max 100, default 50
  offset?: number          // For pagination
}
```

### Response

```json
{
  "success": true,
  "count": 10,
  "limit": 50,
  "offset": 0,
  "results": [
    {
      "id": 123,
      "candidate_id": 4567,
      "name": "NAME",
      "office_type": "LOK_SABHA",
      "state": "STATE",
      "constituency": "CONSTITUENCY",
      "party": "PARTY",
      "self_profession": "Profession",
      "spouse_profession": "Profession",
      "image_url": "https://...",
      "assets": 144008066,
      "liabilities": 18427959,
      "education": "Education details",
      "total_cases": 5,
      "ipc_cases_count": 3,
      "bns_cases_count": 2
    }
  ]
}
```

---

## 2. Get Single Representative

```http
GET /v2/representatives/:id
```

### Response

```json
{
  "success": true,
  "data": {
    "id": 123,
    "candidate_id": 4567,
    "name": "NAME",
    "office_type": "LOK_SABHA",
    "state": "STATE",
    "constituency": "CONSTITUENCY",
    "party": "PARTY",
    "term": "2024-2029",
    "self_profession": "Profession",
    "spouse_profession": "Profession",
    "image_url": "https://...",
    "assets": 144008066,
    "liabilities": 18427959,
    "education": "Education details",
    "self_itr": {
      "2023 - 2024": 5000000,
      "2022 - 2023": 4500000
    },
    "spouse_itr": {
      "2023 - 2024": 3000000
    },
    "ipc_cases": [
      "charges related to..."
    ],
    "bns_cases": []
  }
}
```

---

## 3. Statistics

```http
GET /v2/representatives/stats
```

### Response

```json
{
  "success": true,
  "data": {
    "total_representatives": 4200,
    "total_states": 35,
    "total_parties": 150,
    "lok_sabha_count": 543,
    "rajya_sabha_count": 245,
    "state_assembly_count": 3200,
    "vidhan_parishad_count": 212,
    "total_assets": "5000000000000",
    "avg_assets": "150000000",
    "max_assets": 11082483840,
    "min_assets": 100000,
    "representatives_with_assets": 4180,
    "total_cases": 8500,
    "representatives_with_cases": 1200
  }
}
```

---

## 4. Top by Assets

```http
GET /v2/representatives/top-assets?limit=10
```

### Query Parameters

```typescript
{
  limit?: number  // Max 50, default 10
}
```

### Response

```json
{
  "success": true,
  "count": 10,
  "results": [
    {
      "id": 123,
      "candidate_id": 456,
      "name": "NAME",
      "office_type": "STATE_ASSEMBLY",
      "state": "STATE",
      "constituency": "CONSTITUENCY",
      "party": "PARTY",
      "assets": 11082483840,
      "liabilities": 864235220,
      "net_worth": 10218248620
    }
  ]
}
```

---

## 5. Most Criminal Cases

```http
GET /v2/representatives/most-cases?limit=10
```

### Query Parameters

```typescript
{
  limit?: number  // Max 50, default 10
}
```

### Response

```json
{
  "success": true,
  "count": 10,
  "results": [
    {
      "id": 123,
      "candidate_id": 456,
      "name": "NAME",
      "office_type": "STATE_ASSEMBLY",
      "state": "STATE",
      "constituency": "CONSTITUENCY",
      "party": "PARTY",
      "total_cases": 25,
      "ipc_cases": 20,
      "bns_cases": 5
    }
  ]
}
```

---

## 6. Get States

```http
GET /v2/metadata/states
```

### Response

```json
{
  "success": true,
  "count": 35,
  "data": [
    "ANDHRA PRADESH",
    "BIHAR",
    "GUJARAT",
    ...
  ]
}
```

---

## 7. Get Parties

```http
GET /v2/metadata/parties
```

### Response

```json
{
  "success": true,
  "count": 150,
  "data": [
    { "party": "BJP", "count": 1500 },
    { "party": "INC", "count": 800 },
    { "party": "AAP", "count": 95 }
  ]
}
```

---

## Example Usage

### JavaScript/TypeScript

```typescript
const BASE_URL = 'https://ratemymantri.sallytion.qzz.io/v2';

// Search
const searchReps = async (query: string) => {
  const res = await fetch(`${BASE_URL}/representatives/search?q=${query}`);
  return res.json();
};

// Get details
const getRep = async (id: number) => {
  const res = await fetch(`${BASE_URL}/representatives/${id}`);
  return res.json();
};

// Get stats
const getStats = async () => {
  const res = await fetch(`${BASE_URL}/representatives/stats`);
  return res.json();
};

// Get richest
const getRichest = async (limit = 10) => {
  const res = await fetch(`${BASE_URL}/representatives/top-assets?limit=${limit}`);
  return res.json();
};
```

### Python

```python
import requests

BASE_URL = 'https://ratemymantri.sallytion.qzz.io/v2'

# Search
def search_reps(query):
    response = requests.get(f'{BASE_URL}/representatives/search', params={'q': query})
    return response.json()

# Get details
def get_rep(rep_id):
    response = requests.get(f'{BASE_URL}/representatives/{rep_id}')
    return response.json()

# Get stats
def get_stats():
    response = requests.get(f'{BASE_URL}/representatives/stats')
    return response.json()
```

### cURL

```bash
# Search by name
curl "https://ratemymantri.sallytion.qzz.io/v2/representatives/search?q=modi"

# Get Lok Sabha members
curl "https://ratemymantri.sallytion.qzz.io/v2/representatives/search?officeType=LOK_SABHA&limit=100"

# Get details
curl "https://ratemymantri.sallytion.qzz.io/v2/representatives/123"

# Get stats
curl "https://ratemymantri.sallytion.qzz.io/v2/representatives/stats"

# Get top 10 richest
curl "https://ratemymantri.sallytion.qzz.io/v2/representatives/top-assets?limit=10"

# Get representatives with most cases
curl "https://ratemymantri.sallytion.qzz.io/v2/representatives/most-cases?limit=20"
```

---

## Error Responses

### 400 Bad Request
```json
{
  "success": false,
  "error": "Invalid representative ID"
}
```

### 404 Not Found
```json
{
  "success": false,
  "error": "Representative not found"
}
```

### 500 Internal Server Error
```json
{
  "success": false,
  "error": "Failed to fetch data"
}
```

---

## Rate Limiting

All endpoints are cached:
- Search/Details: 5 minutes
- Stats/Top/Most: 10 minutes  
- Metadata: 1 hour

No additional rate limiting is applied.

---

## Data Fields Explained

| Field | Type | Description |
|-------|------|-------------|
| `id` | number | Internal database ID |
| `candidate_id` | number | Original source data ID |
| `name` | string | Full name |
| `office_type` | string | LOK_SABHA, RAJYA_SABHA, STATE_ASSEMBLY, VIDHAN_PARISHAD |
| `state` | string | State name |
| `constituency` | string | Constituency name (null for Rajya Sabha) |
| `party` | string | Political party |
| `term` | string | Term period (for Rajya Sabha, e.g., "2020-2026") |
| `self_profession` | string | Representative's profession |
| `spouse_profession` | string | Spouse's profession |
| `image_url` | string | Profile image URL |
| `assets` | number | Total assets in rupees |
| `liabilities` | number | Total liabilities in rupees (null = none) |
| `education` | string | Education details |
| `self_itr` | object | ITR by year `{"2023-2024": 5000000}` |
| `spouse_itr` | object | Spouse ITR by year |
| `ipc_cases` | array | IPC criminal case descriptions |
| `bns_cases` | array | BNS criminal case descriptions |
| `total_cases` | number | Total criminal cases count |
| `net_worth` | number | Assets - Liabilities |

---

## Office Types

- **LOK_SABHA**: Members of Parliament (Lower House)
- **RAJYA_SABHA**: Members of Parliament (Upper House)
- **STATE_ASSEMBLY**: State Legislative Assembly Members (MLAs)
- **VIDHAN_PARISHAD**: State Legislative Council Members (MLCs)

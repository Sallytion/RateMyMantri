Below is a **single, comprehensive Markdown document** you can keep as **`ARCHITECTURE.md`** (or similar).
It documents **everything you have built so far**: architecture, auth flow, DB schema, services, ports, secrets, versions, and security assumptions.

You can copy–paste this **as-is**.

---

```md
# Rate My Mantri — Backend Architecture & Setup (v1)

## Overview

This document describes the **complete backend architecture** for the *Rate My Mantri* application, including:

- Infrastructure
- Authentication & authorization
- Database schema
- API flows
- Security model
- Deployment & services
- Versions and configuration

This backend is designed to be:
- Secure-by-default
- Mobile-first (Android client)
- Cloudflare Zero Trust–protected
- Production-ready

---

## 1. High-Level Architecture

```

Android App
|
| HTTPS (JWT)
v
Cloudflare Tunnel (Zero Trust)
|
v
Express Backend (localhost:8085)
|
+--> PostgreSQL (users, ratings, tokens)
+--> Redis (future: rate limits, anon tokens)

```

### Key Properties
- Backend is **never publicly exposed**
- All traffic flows through **Cloudflare Tunnel**
- No secrets stored in Android app
- Google identity verified server-side
- Backend issues its own JWTs

---

## 2. Infrastructure

### Server
- Oracle Cloud Free Tier
- ARM VM
- 4 OCPU
- 24 GB RAM
- Ubuntu Linux

### Base Paths
```

/data/rateMyMantri/
├── backend/
├── postgres/
└── redis/

```

---

## 3. Services & Ports

| Service | Port | Exposure |
|------|----|----|
| Express backend | 8085 | localhost only |
| PostgreSQL | 5432 | localhost only |
| Redis | 6379 | localhost only |
| Cloudflare Tunnel | N/A | public HTTPS |

---

## 4. Backend Service (Express)

### Runtime
- Node.js ≥ 18
- Express (ES Modules)

### Systemd Service
File:
```

/etc/systemd/system/ratemymantri-backend.service

```

Purpose:
- Auto-start on boot
- Auto-restart on crash
- Non-root execution

---

## 5. Environment Variables (Backend)

**File**
```

/data/rateMyMantri/backend/.env

````

### Core
```env
PORT=8085
NODE_ENV=production
````

### Database

```env
DATABASE_URL=postgresql://weRateMantris:<PASSWORD>@127.0.0.1:5432/rate_my_mantri
```

### Google Auth

```env
GOOGLE_CLIENT_ID=917168657465-36uueqrmcjh0ufkn46015hag53lbthfh.apps.googleusercontent.com
```

### JWT Secrets

```env
JWT_ACCESS_SECRET=<LONG_RANDOM_STRING>
JWT_REFRESH_SECRET=<LONG_RANDOM_STRING>
```

### Aadhaar Hashing (future)

```env
AADHAAR_HASH_SALT=<SERVER_SIDE_SECRET>
```

⚠️ These variables **never exist in the Android app**.

---

## 6. Authentication Model

### Identity Source

* Google Sign-In (Android)
* Backend verifies Google ID token using Google public keys

### Trust Boundary

* Google token is used **only once** (`/auth/google`)
* After that, **only backend JWTs are trusted**

---

## 7. Token Strategy (Type B)

### Access Token

* Format: JWT
* Expiry: **15 minutes**
* Stored: Android Keystore
* Used for: all protected APIs

### Refresh Token

* Format: JWT
* Expiry: **365 days**
* Stored:

  * Android Keystore
  * PostgreSQL (`refresh_tokens` table)
* Revocable

---

## 8. Authentication Flow

### Login Flow

```
Android
 └─ Google Sign-In
     └─ idToken
        ↓
POST /auth/google
        ↓
Verify with Google
        ↓
Upsert user
        ↓
Issue JWTs
```

### Protected API Flow

```
Android
 └─ Authorization: Bearer <accessToken>
        ↓
JWT verification
        ↓
req.user injected
        ↓
API logic
```

---

## 9. API Endpoints

### Health Check

```
GET /health
```

Response:

```json
{
  "status": "ok",
  "db": "connected",
  "time": "ISO_TIMESTAMP"
}
```

---

### Google Login

```
POST /auth/google
Content-Type: application/json
```

Body:

```json
{
  "idToken": "<GOOGLE_ID_TOKEN>"
}
```

Response:

```json
{
  "success": true,
  "user": {
    "id": "uuid",
    "email": "user@gmail.com",
    "name": "User",
    "profileImage": "...",
    "isVerified": false
  },
  "tokens": {
    "accessToken": "jwt",
    "refreshToken": "jwt"
  }
}
```

---

### Get Current User (Protected)

```
GET /me
Authorization: Bearer <accessToken>
```

---

## 10. Middleware

### JWT Auth Middleware

* File: `src/middleware/auth.js`
* Responsibilities:

  * Parse `Authorization` header
  * Verify JWT signature
  * Enforce expiry
  * Attach `req.user`

---

## 11. Database Schema

### users

```sql
id UUID PRIMARY KEY
google_id TEXT UNIQUE
email TEXT UNIQUE
name TEXT
profile_image TEXT
is_verified BOOLEAN
aadhaar_hash CHAR(64) UNIQUE NULL
created_at TIMESTAMPTZ
```

### refresh_tokens

```sql
id UUID PRIMARY KEY
user_id UUID REFERENCES users(id)
token TEXT
expires_at TIMESTAMPTZ
created_at TIMESTAMPTZ
```

### mantris

```sql
id UUID
name TEXT
party TEXT
house ENUM(lok_sabha, rajya_sabha)
constituency TEXT
state TEXT
image_url TEXT
```

### ratings

```sql
id UUID
user_id UUID
mantri_id UUID
rating INT (1–5)
comment TEXT
is_anonymous BOOLEAN
```

---

## 12. Aadhaar Handling (Planned)

### Rules

* Aadhaar is **optional**
* Aadhaar is **never stored**
* Only a **one-way hash** is stored
* Used only to prevent duplicate accounts

### Hashing

```
SHA256(aadhaar_qr_string + AADHAAR_HASH_SALT)
```

---

## 13. Cloudflare Tunnel

### Purpose

* Hide origin IP
* Enforce HTTPS
* DDoS & bot protection
* Zero Trust model

### Ingress

```yaml
hostname: ratemymantri.sallytion.qzz.io
service: http://localhost:8085
```

---

## 14. Security Guarantees

* No backend ports exposed
* No secrets in mobile app
* Google identity verified server-side
* JWT expiry enforced
* Refresh tokens revocable
* DB isolated on localhost

---

## 15. Versions

| Component           | Version |
| ------------------- | ------- |
| Node.js             | ≥ 18    |
| Express             | latest  |
| PostgreSQL          | 16      |
| Redis               | 7       |
| google-auth-library | latest  |
| jsonwebtoken        | latest  |

---

## 16. Next Planned Steps

1. Refresh token rotation (`/auth/refresh`)
2. Aadhaar QR hashing flow
3. Anonymous rating enforcement
4. Swagger docs (protected)
5. Mantri & rating APIs
6. Redis rate limiting

---

## 17. Non-Goals (Explicit)

* No Aadhaar verification claims
* No client-side auth trust
* No public DB exposure
* No plaintext secrets

---

## Status

✅ Authentication complete
✅ Authorization complete
✅ Infrastructure stable
🟡 Feature APIs pending

---

End of document.

```

---

### What to do next

**Strongly recommended next steps (in order):**
1. `/auth/refresh` (token rotation)
2. Aadhaar hash flow
3. Anonymous rating rules
4. Swagger (admin-only)

Tell me **which one you want next**, and we continue with the same level of rigor.
```

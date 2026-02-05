# Ratings System - API Documentation

## Overview
The ratings system allows users to rate representatives (MLAs, MPs-Lok Sabha, MPs-Rajya Sabha, MLCs) with three questions, each rated 1-5 stars.

## Rating Types
1. **Unverified** - Any logged-in user (not Aadhaar verified)
2. **Verified-Named** - Aadhaar verified user, shows their name
3. **Verified-Anonymous** - Aadhaar verified user, stays anonymous

## Rating Questions by Office Type

### MLA (STATE_ASSEMBLY)
1. **Local Issue Resolution** - "How effectively has this MLA addressed local constituency issues (roads, water, safety, basic services)?"
2. **Work in State Assembly** - "How active and effective has this MLA been in the State Assembly (attendance, debates, questions, bills)?"
3. **Accessibility & Trust** - "How accessible, responsive, and trustworthy has this MLA been toward citizens?"

### MP – Lok Sabha (LOK_SABHA)
1. **Constituency Representation** - "How well has this MP represented and developed their parliamentary constituency?"
2. **Parliamentary Performance** - "How effective has this MP been in Parliament (questions, debates, laws, national issues)?"
3. **Integrity & Accountability** - "How honest, transparent, and accountable do you believe this MP is?"

### MP – Rajya Sabha (RAJYA_SABHA)
1. **Policy & Legislative Contribution** - "How meaningful has this MP's contribution been to national laws and policies?"
2. **Expertise & Debate Quality** - "How strong has this MP been in debates, committees, and subject-matter discussions?"
3. **Integrity & Independence** - "How independent, ethical, and accountable has this MP been in their role?"

### MLC (VIDHAN_PARISHAD)
1. **Legislative Scrutiny** - "How effectively has this MLC reviewed, questioned, and improved legislation?"
2. **Knowledge & Policy Input** - "How valuable has this MLC's expertise or experience been in legislative discussions?"
3. **Public Responsibility & Ethics** - "How responsible, ethical, and accountable has this MLC been in public life?"

## Overall Score Calculation
- Each star rating is converted to a score: 1★=20, 2★=40, 3★=60, 4★=80, 5★=100
- Overall score = (Q1 + Q2 + Q3) / 3
- Displayed as stars: 0-20=1★, 21-40=2★, 41-60=3★, 61-80=4★, 81-100=5★

## API Endpoints

### Create Rating
```
POST /api/ratings
Authorization: Bearer <jwt_token>

Body:
{
  "representativeId": 12345,
  "anonymous": false,           // Optional, default: false (only for verified users)
  "question1Stars": 5,           // 1-5
  "question2Stars": 4,           // 1-5
  "question3Stars": 5,           // 1-5
  "reviewText": "Great work!"    // Optional
}

Response:
{
  "success": true,
  "rating": {
    "id": "uuid",
    "representativeId": 12345,
    "ratingType": "verified-named",
    "question1Stars": 5,
    "question2Stars": 4,
    "question3Stars": 5,
    "overallScore": 93,
    "reviewText": "Great work!",
    "createdAt": "2026-01-17T23:00:00Z"
  }
}
```

### Update Rating
```
PUT /api/ratings/:ratingId
Authorization: Bearer <jwt_token>

Body:
{
  "anonymous": true,        // Optional - change anonymity
  "question1Stars": 4,      // Optional - update any question
  "question2Stars": 5,
  "question3Stars": 4,
  "reviewText": "Updated!"  // Optional
}
```

### Delete Rating
```
DELETE /api/ratings/:ratingId
Authorization: Bearer <jwt_token>
```

### Get Ratings for Representative (Public)
```
GET /api/ratings/representative/:representativeId?limit=50&offset=0&sortBy=created_at&sortOrder=DESC

Response:
{
  "success": true,
  "representativeId": 12345,
  "statistics": {
    "total_ratings": 150,
    "avg_overall_score": 78.5,
    "overall_stars": 4
  },
  "ratings": [
    {
      "id": "uuid",
      "ratingType": "verified-named",
      "question1Stars": 5,
      "question2Stars": 4,
      "question3Stars": 5,
      "overallScore": 93,
      "reviewText": "Great work!",
      "userName": "Yash Tekwani",          // Only for verified-named
      "userProfileImage": "https://...",   // Only for verified-named
      "createdAt": "2026-01-17T23:00:00Z",
      "updatedAt": "2026-01-17T23:00:00Z"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0,
    "count": 50
  }
}
```

### Get Rating Statistics (Public)
```
GET /api/ratings/statistics/:representativeId

Response:
{
  "success": true,
  "representativeId": 12345,
  "statistics": {
    "totalRatings": 150,
    "verifiedNamedCount": 80,
    "verifiedAnonymousCount": 50,
    "unverifiedCount": 20,
    "avgOverallScore": 78.5,
    "avgQ1Stars": 4.2,
    "avgQ2Stars": 3.8,
    "avgQ3Stars": 4.0,
    "overallStars": 4,
    "latestRatingDate": "2026-01-17T23:00:00Z",
    "representative": {
      "name": "ADITYANATH",
      "officeType": "LOK_SABHA",
      "state": "GORAKHPUR",
      "constituency": "GORAKHPUR URBAN",
      "party": "BJP"
    }
  }
}
```

### Get Current User's Ratings
```
GET /api/ratings/user/me
Authorization: Bearer <jwt_token>

Response:
{
  "success": true,
  "ratings": [
    {
      "id": "uuid",
      "representativeId": 12345,
      "representativeName": "ADITYANATH",
      "representativeImage": "https://...",
      "officeType": "LOK_SABHA",
      "state": "GORAKHPUR",
      "constituency": "GORAKHPUR URBAN",
      "party": "BJP",
      "ratingType": "verified-named",
      "question1Stars": 5,
      "question2Stars": 4,
      "question3Stars": 5,
      "overallScore": 93,
      "reviewText": "Great work!",
      "createdAt": "2026-01-17T23:00:00Z",
      "updatedAt": "2026-01-17T23:00:00Z"
    }
  ]
}
```

### Check if User Rated a Representative
```
GET /api/ratings/user/me/representative/:representativeId
Authorization: Bearer <jwt_token>

Response:
{
  "success": true,
  "hasRated": true,
  "rating": {
    "id": "uuid",
    "ratingType": "verified-named",
    "question1Stars": 5,
    "question2Stars": 4,
    "question3Stars": 5,
    "overallScore": 93,
    "reviewText": "Great work!",
    "createdAt": "2026-01-17T23:00:00Z",
    "updatedAt": "2026-01-17T23:00:00Z"
  }
}
```

## Constraints
- ✅ Each user can rate each representative only **once** (can update/delete later)
- ✅ Star ratings must be integers between **1-5**
- ✅ Only verified users can post anonymously
- ✅ Users can only update/delete their **own** ratings
- ✅ Review text is optional

## Database Tables
- `ratings` - Stores all ratings
- `rating_statistics` - View with aggregated statistics per representative

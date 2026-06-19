# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev        # Start with nodemon (auto-reload)
npm start          # Production start
npm run db:init    # Initialize PostgreSQL schema (run once)
```

No test or lint tooling is configured.

## Architecture

**Pulse Backend** is a Node.js/Express REST API for nutritional health tracking with AI-powered features and doctor-patient management.

### Request Flow

```
Client → Express (src/index.js)
  → Helmet / CORS / Rate limiter (100 req/15 min)
  → auth.middleware.js (Bearer token + role check)
  → Route handler (src/routes/*.routes.js)
  → PostgreSQL pool (src/config/db.js)
       └── External APIs (Gemini, Groq, Firebase, OpenFoodFacts)
```

### Key Directories

- `src/index.js` — Server bootstrap, route mounting, Socket.io initialization
- `src/config/db.js` — PostgreSQL connection pool (single shared pool)
- `src/config/initDb.js` — Full schema DDL; run `npm run db:init` to apply
- `src/config/firebase.js` — Firebase Admin SDK (Auth + Storage)
- `src/config/socket.js` — Socket.io real-time event handlers
- `src/middleware/auth.middleware.js` — `authenticate()` and `requireRole()` — Bearer-token check against the `users` table
- `src/routes/` — One file per domain, mounted under `/api/<domain>`
- `src/services/agent.service.js` — Gemini 2.0 Flash chatbot with per-user conversation history stored in DB
- `src/services/photo.service.js` — Groq Vision (Llama 4 Scout 17B) meal photo analysis

### Database

PostgreSQL (`pulse_db`). Key tables:

| Table | Purpose |
|---|---|
| `users` | Accounts (UUID PK, Firebase UID, role: `user`/`doctor`) |
| `nutrition_profiles` | Calorie/macro targets; BMR & TDEE calculated on insert |
| `meals` + `meal_items` | Meal logs with per-item nutrition |
| `discipline_scores` | Daily score (calories 40 pts, macros 30 pts, photos 20 pts, weight 10 pts) |
| `foods_tn` | Tunisian food database (bilingual FR/AR) |
| `conversations` | Gemini chat history per user |
| `doctor_access` | Doctor-patient relationships (`pending`/`approved`) |
| `doctor_profiles` | Doctor credentials & specialty |
| `water_logs_daily` | Daily water intake |
| `notifications` | In-app notifications |

### External Services

- **Gemini AI** (`@google/genai`) — `/api/agent` chatbot
- **Groq Vision** (`groq-sdk`) — `/api/meals/analyze-photo`
- **Firebase Admin** — Auth token verification + file storage
- **OpenFoodFacts** (via `axios`) — Barcode scan (`/api/meals/scan/:barcode`) and food search

### Environment Variables

Required in `.env`:

```
PORT=3000
DATABASE_URL=postgresql://user:pass@localhost:5432/pulse_db
GEMINI_API_KEY=
GROQ_API_KEY=
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=
FIREBASE_STORAGE_BUCKET=
ADMIN_USERNAME=
ADMIN_PASSWORD=
```

### Auth

- Most endpoints call `authenticate()` middleware which resolves the Bearer token to a user row.
- `requireRole('doctor')` is used on doctor-only routes.
- Admin routes use a separate header-based basic auth check (username/password from env).

### Code Conventions

- All comments and user-facing messages are in **French**.
- Async/await throughout; no callback style.
- SQL uses parameterized queries (`$1`, `$2`, …) via `pg` pool.
- No ORM — raw SQL in route handlers.
- UUIDs generated with the `uuid` package for all primary keys.

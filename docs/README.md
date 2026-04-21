# LEGO Brick Detection & Inventory App

A full-stack application that uses Azure Custom Vision to identify and classify LEGO bricks from photos or live camera input. It maintains a personal brick inventory and recommends buildable LEGO sets based on what you own.

---

## Table of Contents

- [Features](#features)
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Setup & Installation](#setup--installation)
- [Environment Variables](#environment-variables)
- [Running the App](#running-the-app)
- [API Reference](#api-reference)
- [Project Structure](#project-structure)
- [Known Limitations](#known-limitations)

---

## Features

- **Brick Detection** — Upload or photograph LEGO bricks; Azure Custom Vision identifies brick type and colour
- **Inventory Management** — Add detected bricks to a personal inventory; adjust quantities; filter by colour
- **Set Recommendations** — Matches your inventory against a set catalogue and shows completion percentage and missing pieces
- **Scan History** — Browse past scans with expandable brick details
- **User Accounts** — JWT-based authentication; each user has their own inventory and scan history
- **Camera Capture** — Live camera preview on desktop and mobile via the `camera` package

---

## Architecture Overview

```
┌─────────────────────────────┐        ┌──────────────────────────────────┐
│   Flutter Frontend (lib/)   │  HTTP  │      Flask Backend (backend/)    │
│                             │◄──────►│                                  │
│  • Scan screen              │        │  • /api/upload   (detection)     │
│  • Inventory screen         │        │  • /api/inventory                │
│  • Recommendations screen   │        │  • /api/recommendations          │
│  • Scan history screen      │        │  • /api/scan-history             │
│  • Auth (login/register)    │        │  • /api/auth/*                   │
└─────────────────────────────┘        └──────────┬───────────────────────┘
                                                   │
                              ┌────────────────────┼──────────────────┐
                              │                    │                  │
                    ┌─────────▼──────┐   ┌─────────▼──────┐  ┌───────▼──────┐
                    │ Azure Custom   │   │   SQLite DB    │  │  Pinecone    │
                    │ Vision API     │   │ (lego_app.db)  │  │  (optional)  │
                    └────────────────┘   └────────────────┘  └──────────────┘
```

**Request flow for a scan:**
1. Flutter uploads image (multipart or base64) to `POST /api/upload`
2. Flask saves the file to `uploads/`
3. `AzureDetector.detect_bricks()` sends image bytes to Azure Custom Vision
4. Azure returns bounding boxes + class labels + confidence scores
5. Results are filtered by confidence threshold, deduplicated via NMS, and colour-classified using HSV pixel voting
6. Aggregated detections are saved to `ScanHistory` and returned to Flutter
7. Flutter renders result cards with brick name, colour, confidence bar

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter | ≥ 3.19 | Frontend framework |
| Dart | ≥ 3.3 | Flutter language |
| Python | ≥ 3.10 | Backend runtime |
| pip | ≥ 23 | Python package manager |
| Azure Custom Vision | — | Brick detection model |

---

## Setup & Installation

### 1. Clone the repository

```bash
git clone <repo-url>
cd Lego-Brick-Counter
```

### 2. Backend setup

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate
# macOS / Linux
source venv/bin/activate

pip install -r requirements.txt
```

Copy the example environment file and fill in your credentials:

```bash
cp .env.example .env
```

### 3. Frontend setup

```bash
cd frontend
flutter pub get
```

---

## Environment Variables

Create a `.env` file in `backend/` with the following keys:

```env
# ── Azure Custom Vision ─────────────────────────────────────────
AZURE_CV_PREDICTION_KEY=your_prediction_key_here
AZURE_CV_PREDICTION_ENDPOINT=https://your-resource.cognitiveservices.azure.com
AZURE_CV_PROJECT_ID=your_project_uuid
AZURE_CV_PUBLISHED_NAME=Iteration2

# ── Detection tuning ────────────────────────────────────────────
# Lower = more bricks detected but more false positives (0.05–0.30)
CONFIDENCE_THRESHOLD=0.10

# ── Flask ───────────────────────────────────────────────────────
SECRET_KEY=change-this-to-a-random-string
JWT_SECRET_KEY=change-this-to-another-random-string

# ── Database ────────────────────────────────────────────────────
# Defaults to SQLite. For PostgreSQL: postgresql://user:pass@host/dbname
DATABASE_URL=sqlite:///lego_app.db

# ── Pinecone (optional — leave blank to run without vector search) ──
PINECONE_API_KEY=
PINECONE_ENVIRONMENT=
```

> **Never commit `.env` to version control.** It is already in `.gitignore`.

---

## Running the App

### Start the backend

```bash
cd backend
# Activate venv first (see Setup above)
flask --app app run --debug --host 0.0.0.0 --port 5000
```

The API will be available at `http://localhost:5000`.

### Start the Flutter app

```bash
cd frontend
flutter run -d windows   # Windows desktop
flutter run -d macos     # macOS desktop
flutter run -d chrome    # Web
flutter run              # Connected mobile device
```

> **Android emulator:** The backend URL is automatically set to `http://10.0.2.2:5000` — no config needed.

---

## API Reference

All endpoints except `/api/auth/register`, `/api/auth/login`, and `/api/health` require an `Authorization: Bearer <token>` header.

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Create a new account |
| POST | `/api/auth/login` | Log in, receive JWT token |
| GET | `/api/auth/profile` | Get current user profile + stats |
| POST | `/api/auth/logout` | Invalidate session (client-side) |
| POST | `/api/upload` | Upload image for brick detection |
| GET | `/api/inventory` | Get user's brick inventory |
| POST | `/api/inventory` | Add bricks to inventory |
| PUT | `/api/inventory/<brick_id>` | Update quantity of a brick |
| DELETE | `/api/inventory/<brick_id>` | Remove a brick from inventory |
| GET | `/api/recommendations` | Get set recommendations based on inventory |
| GET | `/api/scan-history` | Get past scan results |
| DELETE | `/api/scan-history` | Clear all scan history |
| GET | `/api/health` | Health check (no auth required) |

---

## Project Structure

```
Lego-Brick-Counter/
│
├── backend/
│   ├── app.py                  # Flask app, routes, DB models
│   ├── azure_detector.py       # Azure Custom Vision wrapper + colour detection
│   ├── brick_detector.py       # ONNX fallback detector
│   ├── color_detector.py       # HSV colour classifier (used by ONNX path)
│   ├── pinecone_service.py     # Pinecone vector DB integration
│   ├── recommendations_routes.py  # Set recommendation logic
│   ├── requirements.txt
│   ├── .env.example
│   └── uploads/                # Uploaded images (git-ignored)
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart           # App entry point, all screens
│   │   ├── camera_screen.dart  # Live camera capture screen
│   │   └── services/
│   │       ├── api_service.dart   # All HTTP calls to backend
│   │       └── auth_service.dart  # Auth state + token persistence
│   ├── pubspec.yaml
│   └── assets/
│
└── docs/
    ├── README.md               # This file
    ├── ARCHITECTURE.md         # Detailed system design decisions
    ├── API.md                  # Full API request/response examples
    └── CHANGELOG.md            # Version history
```

---

## Known Limitations

- **Detection accuracy** depends on Azure Custom Vision model training quality. Low-confidence detections (below `CONFIDENCE_THRESHOLD`) are filtered out, so some bricks in cluttered images may be missed.
- **Colour classification** uses HSV pixel voting and can misidentify colours in poor lighting or on shiny/transparent bricks.
- **Set catalogue** in `recommendations_routes.py` currently contains 5 sets. Expand `_SET_CATALOG` to add more.
- **Camera on desktop** requires the `camera` Flutter package. Flash control may not work on all laptop webcams.
- **Pinecone** is optional. Without it, recommendations fall back to local catalogue matching only.
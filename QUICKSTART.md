# Lego Brick Counter - Quick Start Guide

## ✅ Verification Status
All tests passing! Backend and frontend are fully compatible.

### Test Results
- ✓ **11/11 Integration tests passed** (run `test_integration.py`)
- ✓ **8/8 Frontend API contracts validated** (run `test_frontend_api.py`)
- ✓ Backend compiles (Python 3.9+, numpy 2.4.2+)
- ✓ Frontend compiles (Flutter 3+, Dart 3+)

---

## 🚀 Running the Project

### Prerequisites
- **Python 3.9+** (tested on 3.13.2)
- **Flutter 3.0+** with Dart 3.0+
- **Node.js/npm** (optional, if needed for web build)

### Backend Setup

1. **Install Python dependencies:**
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **(Optional) Create `.env` file for Pinecone:**
   ```bash
   cp .env.example .env
   # Edit .env with your Pinecone API key if you want vector search
   ```

3. **Start the Flask server:**
   ```bash
   python app.py
   ```
   Server runs on `http://localhost:5000`

### Frontend Setup

#### Windows Desktop
```bash
cd frontend
flutter pub get
flutter run -d windows
```

#### Web
```bash
cd frontend
flutter pub get
flutter run -d chrome
# or: flutter run -d edge
```

#### Android Emulator
```bash
cd frontend
flutter pub get
flutter run
# Make sure emulator is running or device is connected
```

**Note:** The app connects to `http://localhost:5000/api` on web/desktop, and `http://10.0.2.2:5000/api` on Android emulator.

---

## 📝 Testing

### Run Integration Tests
```bash
python test_integration.py
```
Tests 11 major API endpoints (health, upload, inventory, recommendations, etc.)

### Run Frontend API Validation
```bash
python test_frontend_api.py
```
Validates that Flutter screens will work with the backend responses.

### Run Flutter Widget Tests
```bash
cd frontend
flutter test
```

---

## 🔍 Project Structure

```
backend/
├── app.py                   # Flask API
├── brick_detector.py        # ONNX model handler
├── pinecone_service.py      # Vector DB integration
├── requirements.txt         # Python dependencies
├── best.onnx               # YOLOv8 model (must be present)
├── class_names.txt         # Model class labels
└── uploads/                # Image storage (gitignored)

frontend/
├── lib/
│   ├── main.dart           # App entry point + all screens
│   └── services/
│       └── api_service.dart # HTTP client (web/native support)
├── pubspec.yaml            # Flutter dependencies
└── test/
    └── widget_test.dart    # Flutter widget tests

test_integration.py         # Backend API tests
test_frontend_api.py        # Frontend contract validation
```

---

## 🛠️ Key Features Working

### Backend (Flask)
✓ Image upload (multipart + base64 for web)  
✓ ONNX model inference (brick detection)  
✓ Brick metadata lookup  
✓ Set metadata lookup  
✓ Inventory management (GET/POST/PUT/DELETE)  
✓ Set recommendations (local + Pinecone)  
✓ Vector similarity search (Pinecone optional)  
✓ Comprehensive error handling  

### Frontend (Flutter)
✓ Multi-platform (Windows, Web, Android, iOS)  
✓ Image picker (camera + gallery)  
✓ Real-time brick detection  
✓ Inventory management UI  
✓ Set recommendations display  
✓ Auto-detect color from brick image  
✓ Status monitoring (backend health)  

---

## 🔧 Troubleshooting

### Backend won't start
- **Numpy errors on Python 3.13?** → Run `pip install --force-reinstall "numpy>=2.0.0"`
- **Model file missing?** → Place `best.onnx` in `/backend/`
- **Port 5000 in use?** → Change port in `app.py` line ~745: `app.run(..., port=5001)`

### Frontend won't compile
- **Generic types error?** → Update Flutter: `flutter upgrade`
- **Missing pubspec packages?** → Run `flutter pub get`
- **Image.file() error?** → Already fixed—uses `Image.memory()` instead for web compatibility

### App can't reach backend
- **Desktop/Web:** Backend must run on `http://localhost:5000`
- **Android Emulator:** Uses `http://10.0.2.2:5000` (host machine localhost)
- **iOS Simulator:** Uses `http://localhost:5000`
- **Real device:** Set backend IP in [api_service.dart](frontend/lib/services/api_service.dart)

---

## 📦 Environment Variables (Optional)

Set in `.env` for Pinecone integration:

```
PINECONE_API_KEY=your-key-here
PINECONE_INDEX_NAME=lego-bricks
PINECONE_CLOUD=aws
PINECONE_REGION=us-east-1
```

If not set, app runs in **local-only mode** (still fully functional).

---

## 📊 API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/health` | Server status |
| POST | `/api/upload` | Upload & detect bricks |
| POST | `/api/analyze-photo` | Detailed analysis |
| GET | `/api/inventory` | List user bricks |
| POST | `/api/inventory` | Add bricks |
| GET | `/api/recommendations` | Suggest sets |
| GET | `/api/brick/{id}` | Brick details |
| GET | `/api/set/{id}` | Set details |
| POST | `/api/similar` | Find similar bricks |
| GET | `/api/pinecone/stats` | Vector DB stats |

---

## 🎯 Next Steps

1. **Try image upload:** Take a photo of Lego bricks with the app
2. **Build a set:** Use recommendations to find what you can build
3. **Extend model:** Add more brick types by retraining `best.onnx`
4. **Deploy:** Use production WSGI server (gunicorn) + Flutter web build

---

**Last updated:** 2026-02-19  
**Maintainer:** Sidharth Nair

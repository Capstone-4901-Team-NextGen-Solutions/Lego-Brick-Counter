# LEGO Brick Counter - Quick Setup Guide

## 🚀 Quick Start (5 minutes)

### Backend Setup

```bash
# 1. Clone and navigate
git clone https://github.com/Capstone-4901-Team-NextGen-Solutions/Lego-Brick-Counter.git
cd Lego-Brick-Counter/backend

# 2. Install dependencies
pip install -r requirements.txt

# 3. Copy environment file (Azure key already included!)
cp .env.example .env

# 4. Run the backend
python app.py
```

**Expected Output:**
```
✅ Azure Custom Vision detector ready
✅ Color classifier initialized
* Running on http://127.0.0.1:5000
```

---

### Frontend Setup

```bash
# 1. Navigate to frontend
cd frontend

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

---

## 🧪 Testing Detection

1. **Register/Login** in the app
2. Go to **Scan** tab
3. Click **Upload Photo** or **Take Photo**
4. Select an image with LEGO bricks
5. Click **Detect Bricks** button
6. Results appear with brick names, colors, and confidence!

---

## ⚠️ Troubleshooting

### "detector: Not Available"
- Make sure you copied `.env.example` to `.env`
- Check that backend shows "✅ Azure Custom Vision detector ready"

### "Network error" in app
- Backend must be running on `http://localhost:5000`
- Check backend terminal for errors

### "401 Unauthorized"
- Login again (JWT token expired after 1 hour)

---

## 📁 Project Structure

```
backend/
  ├── app.py              # Flask API
  ├── azure_detector.py   # Azure Custom Vision
  ├── color_detector.py   # K-Means color detection
  └── .env               # Config (copy from .env.example)

frontend/
  ├── lib/main.dart      # Flutter app
  └── services/          # API & auth
```

---

## 🎯 Features

- ✅ Azure Custom Vision brick detection
- ✅ K-Means color detection (16 LEGO colors)
- ✅ JWT authentication
- ✅ Inventory management
- ✅ Set recommendations
- ✅ LEGO-themed UI

---

**That's it! You're ready to detect LEGO bricks! 🧱**

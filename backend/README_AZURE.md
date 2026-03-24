# Azure Custom Vision Integration - Setup Guide

## 🎯 Overview

This integration replaces the ONNX detector with **Azure Custom Vision** for LEGO brick detection. The Azure model achieved **93% mAP** with 50 brick classes and includes integrated color detection.

---

## 📦 Files Included

```
backend/
├── azure_detector.py          ← NEW: Azure Custom Vision client
├── app.py                     ← MODIFIED: Uses Azure instead of ONNX
├── .env                       ← MODIFIED: Added Azure credentials
├── requirements.txt           ← MODIFIED: Added Azure SDK
├── test_azure.py              ← NEW: Integration test script
├── pinecone_service.py        ← UNCHANGED: Keep your existing file
└── README_AZURE.md            ← This file
```

---

## 🚀 Quick Start

### Step 1: Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

**New packages installed:**
- `azure-cognitiveservices-vision-customvision==3.1.0`
- `msrest==0.7.1`

**Removed:**
- `onnxruntime` (no longer needed)

### Step 2: Update .env File

Replace your existing `.env` with the new one:

```env
FLASK_ENV=development
FLASK_DEBUG=1
UPLOAD_FOLDER=uploads
MAX_CONTENT_LENGTH=16777216

# Azure Custom Vision
AZURE_CV_PREDICTION_KEY=your-azure-prediction-key-here
AZURE_CV_PREDICTION_ENDPOINT=https://legovisiontraining-prediction.cognitiveservices.azure.com/
AZURE_CV_PROJECT_ID=13f493c3-3c6f-446a-9dd3-ae82dae2c651
AZURE_CV_PUBLISHED_NAME=Iteration2

# Detection settings
DETECTION_BACKEND=azure
CONFIDENCE_THRESHOLD=0.25

# Pinecone (keep your existing key)
PINECONE_API_KEY=your-pinecone-api-key-here
PINECONE_INDEX_NAME=lego-bricks
```

### Step 3: Replace Files

**Replace these files in your `backend/` folder:**

1. **azure_detector.py** → Copy the new file
2. **app.py** → Replace with `app_azure.py` (rename to `app.py`)
3. **.env** → Update with new credentials
4. **requirements.txt** → Replace with new version
5. **test_azure.py** → Add new test script

**Keep these files:**
- `pinecone_service.py` (unchanged)
- Any other custom files you have

### Step 4: Test the Integration

```bash
# Test Azure detector
python test_azure.py

# With a test image
python test_azure.py path/to/test_image.jpg
```

**Expected output:**
```
======================================================================
AZURE CUSTOM VISION INTEGRATION TEST SUITE
======================================================================

1. TESTING ENVIRONMENT VARIABLES
✓ AZURE_CV_PREDICTION_KEY: FJf1qGztLEhaHsNOW...
✓ AZURE_CV_PREDICTION_ENDPOINT: https://legovisiontraining-prediction...
✓ AZURE_CV_PROJECT_ID: 13f493c3-3c6f-446a-9dd3-ae82dae2c651
✓ AZURE_CV_PUBLISHED_NAME: Iteration2

✅ All environment variables present

2. TESTING AZURE DETECTOR
✓ Azure detector module imported
✓ Azure detector initialized
  Endpoint: https://legovisiontraining-prediction.cognitiveservices.azure.com/
  Project: 13f493c3-3c6f-446a-9dd3-ae82dae2c651
  Published: Iteration2
  Threshold: 0.25

✅ Azure detector working!

======================================================================
✅ ALL CORE TESTS PASSED!
======================================================================
```

### Step 5: Start the Server

```bash
python app.py
```

**Expected output:**
```
INFO:__main__:🔄 Initializing Azure Custom Vision...
INFO:__main__:   Endpoint: https://legovisiontraining-prediction.cognitiveservices.azure.com/
INFO:__main__:   Project: 13f493c3-3c6f-446a-9dd3-ae82dae2c651
INFO:__main__:   Published: Iteration2
INFO:__main__:✅ Azure detector initialized (threshold=0.25)
INFO:__main__:✅ Azure Custom Vision detector ready
 * Running on http://0.0.0.0:5000
```

### Step 6: Test the API

```bash
# Test health endpoint
curl http://localhost:5000/api/health

# Test with image
curl -X POST http://localhost:5000/api/upload \
  -F "file=@test_image.jpg"
```

---

## 🎨 Features

### ✅ What Works

1. **Azure Custom Vision Detection**
   - 93% mAP accuracy
   - 50 brick classes
   - Confidence filtering (default 25%)

2. **Color Detection**
   - HSV-based color analysis
   - 13 LEGO standard colors:
     - Red, Orange, Yellow, Lime, Green
     - Cyan, Blue, Purple, Magenta
     - Black, Dark Gray, Light Gray, White, Brown

3. **API Compatibility**
   - Same endpoints as before
   - Same response format
   - Frontend code needs NO changes

4. **LEGO Part Mapping**
   - All 50 Azure classes map to official LEGO IDs
   - Supports all bricks, plates, and tiles

### 📊 Response Format

```json
{
  "success": true,
  "bricks_detected": 5,
  "detector": "Azure Custom Vision",
  "results": [
    {
      "id": "3001",
      "name": "Brick 2 x 4",
      "color": "Red",
      "quantity": 2,
      "confidence": 0.95,
      "bbox": [100, 150, 80, 60]
    }
  ],
  "timestamp": "2026-02-26T10:30:00Z"
}
```

---

## 🔧 Configuration

### Confidence Threshold

Adjust in `.env`:
```env
CONFIDENCE_THRESHOLD=0.25  # 25% minimum confidence
```

Lower = more detections (more false positives)
Higher = fewer detections (fewer false positives)

**Recommended:**
- Development: 0.20-0.25
- Production: 0.30-0.40

### Color Detection Tuning

Edit `azure_detector.py` → `_detect_colour()` method to adjust HSV thresholds.

---

## 🐛 Troubleshooting

### Issue 1: "Missing Azure credentials"

**Error:**
```
ValueError: Missing Azure credentials
```

**Fix:**
Check `.env` file has all 4 values:
- AZURE_CV_PREDICTION_KEY
- AZURE_CV_PREDICTION_ENDPOINT
- AZURE_CV_PROJECT_ID
- AZURE_CV_PUBLISHED_NAME

### Issue 2: "Model not found"

**Error:**
```
CustomVisionErrorException: Iteration not found
```

**Fix:**
1. Go to https://www.customvision.ai
2. Check your model is published as "Iteration2"
3. If different name, update `AZURE_CV_PUBLISHED_NAME` in `.env`

### Issue 3: No detections returned

**Possible causes:**
1. Confidence threshold too high
   - Lower it in `.env`: `CONFIDENCE_THRESHOLD=0.15`

2. Model not trained on similar images
   - Check image quality (lighting, focus)
   - Ensure bricks are clearly visible

3. Wrong published iteration
   - Verify `AZURE_CV_PUBLISHED_NAME` matches portal

### Issue 4: Import errors

**Error:**
```
ModuleNotFoundError: No module named 'azure'
```

**Fix:**
```bash
pip install -r requirements.txt
```

---

## 📈 Performance Expectations

### Azure Custom Vision Model Stats

```
Overall mAP:           93%
Average Precision:     93.6%
Average Recall:        86.2%
Perfect Classes:       21/50 (100% accuracy)
Good Classes (>80%):   44/50
Weak Classes (<70%):   3/50

Processing Time:
- Image upload:     ~100ms
- Azure API call:   ~800-1500ms
- Color detection:  ~50ms per brick
- Total:            ~1-2 seconds per image
```

### Cost (Azure Free Tier)

```
✓ 10,000 predictions/month FREE
✓ Sufficient for development
✓ ~330 predictions/day

For production (>10K/month):
  $2 per 1,000 predictions
```

---

## 🔄 Comparison: ONNX vs Azure

| Feature | ONNX (Old) | Azure (New) |
|---------|------------|-------------|
| **Accuracy** | ~70-80% | **93%** ✅ |
| **Classes** | 6 | **50** ✅ |
| **Color Detection** | Basic | **Enhanced** ✅ |
| **Processing Time** | 200-500ms | 1-2 seconds |
| **Cost** | Free | Free (10K/month) |
| **Setup** | Complex | **Simple** ✅ |
| **Maintenance** | Manual | **Auto-updated** ✅ |
| **GPU Required** | No | **No** ✅ |

---

## 🎯 Next Steps

### For Development

1. ✅ Test with various images
2. ✅ Tune confidence threshold
3. ✅ Share API with frontend team
4. ✅ Deploy to production server

### For Production

1. Monitor Azure usage (10K free predictions/month)
2. Set up error logging
3. Add response caching (optional)
4. Consider exporting to ONNX for offline use (optional)

### For Improvement

If you need >93% accuracy:
1. Add 140 more images to weak classes
2. Retrain (takes 1-3 hours)
3. Republish model
4. Update `AZURE_CV_PUBLISHED_NAME` to new iteration

---

## 📞 Support

**Issues:**
- Azure API errors → Check credentials in `.env`
- No detections → Lower confidence threshold
- Wrong detections → Retrain with more data

**Questions:**
- Azure Portal: https://www.customvision.ai
- Azure Docs: https://docs.microsoft.com/azure/cognitive-services/custom-vision-service/

---

## ✅ Deployment Checklist

```
Pre-Deployment:
[ ] Azure credentials in .env
[ ] Dependencies installed (pip install -r requirements.txt)
[ ] test_azure.py passes
[ ] API endpoints tested
[ ] Frontend integration tested

Production:
[ ] Debug mode OFF (FLASK_DEBUG=0)
[ ] Use production WSGI server (gunicorn/uwsgi)
[ ] Set up error logging
[ ] Monitor Azure usage
[ ] Set up backups

Done! Your Azure integration is complete! 🎉
```

---

## 📄 License

Azure Custom Vision integration for LEGO Brick Counter
Version 3.0 - February 2026

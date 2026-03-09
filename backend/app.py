# app.py - Lego Brick Counter API (v3.0 - Azure Custom Vision Integration)

from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import os
import logging
import time
from datetime import datetime, timezone
from functools import wraps

from typing import Optional

from werkzeug.utils import secure_filename
from PIL import Image
import base64
import io
import numpy as np

# Azure detector instead of ONNX
from azure_detector import AzureDetector
from pinecone_service import PineconeService

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------
load_dotenv()

app = Flask(__name__)
CORS(app)

# Configuration
UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", "uploads")
MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", 16 * 1024 * 1024))
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp"}

app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["MAX_CONTENT_LENGTH"] = MAX_CONTENT_LENGTH

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Detector Initialization - AZURE CUSTOM VISION
# ---------------------------------------------------------------------------

detector: Optional[AzureDetector] = None
try:
    conf_threshold = float(os.getenv("CONFIDENCE_THRESHOLD", "0.25"))
    detector = AzureDetector(conf_threshold=conf_threshold)
    logger.info("✅ Azure Custom Vision detector ready")
except Exception as exc:
    logger.warning(f"⚠️  Azure detector unavailable ({exc})")
    logger.warning("    Set Azure credentials in .env file")

# Pinecone
pinecone_svc = PineconeService()

# Seed the set index if Pinecone is live
if pinecone_svc.enabled:
    _seed_sets = [
        {
            "set_id": "10698",
            "name": "Classic Creative Brick Box",
            "total_pieces": 790,
            "difficulty": "beginner",
            "bricks_included": [
                {"id": "3001", "quantity": 12, "color": "Red"},
                {"id": "3001", "quantity": 8, "color": "Blue"},
                {"id": "3003", "quantity": 10, "color": "Yellow"},
                {"id": "3023", "quantity": 15, "color": "Green"},
            ],
            "required_bricks": ["3001", "3003", "3023", "3005"],
        },
        {
            "set_id": "31134",
            "name": "Space Rocket",
            "total_pieces": 837,
            "difficulty": "intermediate",
            "bricks_included": [
                {"id": "3001", "quantity": 15, "color": "White"},
                {"id": "3004", "quantity": 8, "color": "Blue"},
                {"id": "3622", "quantity": 6, "color": "Red"},
            ],
            "required_bricks": ["3001", "3004", "3622", "2456"],
        },
        {
            "set_id": "10302",
            "name": "Optimus Prime",
            "total_pieces": 1508,
            "difficulty": "advanced",
            "bricks_included": [
                {"id": "3001", "quantity": 20, "color": "Red"},
                {"id": "3003", "quantity": 15, "color": "Blue"},
                {"id": "3023", "quantity": 10, "color": "Black"},
                {"id": "2456", "quantity": 5, "color": "Gray"},
                {"id": "3039", "quantity": 8, "color": "Red"},
            ],
            "required_bricks": ["3001", "3003", "3023", "2456", "3039"],
        },
    ]
    pinecone_svc.upsert_sets(_seed_sets)

# ---------------------------------------------------------------------------
# Lego part-number map (extended for 50 Azure classes)
# ---------------------------------------------------------------------------
LEGO_ID_MAP = {
    # Bricks
    'Brick 1 x 1': '3005',
    'Brick 1 x 1 x 5': '2453',
    'Brick 1 x 10': '6111',
    'Brick 1 x 2': '3004',
    'Brick 1 x 2 x 2': '3245',
    'Brick 1 x 2 x 5': '2454',
    'Brick 1 x 3': '3622',
    'Brick 1 x 4': '3010',
    'Brick 1 x 6': '3009',
    'Brick 1 x 8': '3008',
    'Brick 2 x 2': '3003',
    'Brick 2 x 2 Corner': '2357',
    'Brick 2 x 2 Slope': '3039',
    'Brick 2 x 3': '3002',
    'Brick 2 x 4': '3001',
    'Brick 2 x 6': '2456',
    'Brick 2 x 8': '3007',
    
    # Plates
    'Plate 1 x 1': '3024',
    'Plate 1 x 1 Round': '4073',
    'Plate 1 x 10': '4477',
    'Plate 1 x 12': '60479',
    'Plate 1 x 2': '3023',
    'Plate 1 x 3': '3623',
    'Plate 1 x 4': '3710',
    'Plate 1 x 6': '3666',
    'Plate 1 x 8': '3460',
    'Plate 2 x 10': '3832',
    'Plate 2 x 12': '2445',
    'Plate 2 x 16': '4282',
    'Plate 2 x 2': '3022',
    'Plate 2 x 2 Corner': '2420',
    'Plate 2 x 3': '3021',
    'Plate 2 x 4': '3020',
    'Plate 2 x 6': '3795',
    'Plate 2 x 8': '3034',
    'Plate 3 x 3': '11212',
    'Plate 4 x 4': '3031',
    'Plate 4 x 4 Corner': '2639',
    'Plate 4 x 6': '3032',
    'Plate 4 x 8': '3035',
    'Plate 6 x 10': '3033',
    'Plate 6 x 6': '3958',
    
    # Tiles
    'Tile 1 x 3': '63864',
    'Tile 1 x 4': '2431',
    'Tile 1 x 6': '6636',
    'Tile 1 x 8': '4162',
    'Tile 2 x 2': '3068',
    'Tile 2 x 4': '87079',
    
    # Legacy
    "2x4 Brick": "3001",
    "2x2 Brick": "3003",
    "1x2 Plate": "3023",
    "1x1 Brick": "3005",
    "2x6 Brick": "2456",
    "1x4 Brick": "3010",
    "lego_brick": "3001",
}

# Static metadata
BRICK_DB = {
    "3001": {
        "id": "3001",
        "official_name": "Brick 2x4",
        "alternate_names": ["2x4 Brick", "Basic Brick"],
        "colors_available": ["Red", "Blue", "Yellow", "Green", "Black", "White", "Gray"],
        "first_released": "1958",
        "weight_g": 2.32,
        "dimensions_mm": {"length": 31.8, "width": 15.9, "height": 9.6},
        "sets_contained_in": ["10698", "11011", "10717"],
        "category": "Basic Bricks",
        "material": "ABS Plastic",
        "description": "The classic 2x4 Lego brick, first produced in 1958.",
    },
    "3003": {
        "id": "3003",
        "official_name": "Brick 2x2",
        "alternate_names": ["2x2 Brick"],
        "colors_available": ["Red", "Blue", "Yellow", "Green", "Black", "White"],
        "first_released": "1958",
        "weight_g": 1.05,
        "dimensions_mm": {"length": 15.9, "width": 15.9, "height": 9.6},
        "sets_contained_in": ["10698", "11011"],
        "category": "Basic Bricks",
    },
    "3023": {
        "id": "3023",
        "official_name": "Plate 1x2",
        "alternate_names": ["1x2 Plate"],
        "colors_available": ["Red", "Blue", "Yellow", "Green", "Black", "White", "Gray"],
        "first_released": "1963",
        "weight_g": 0.42,
        "dimensions_mm": {"length": 15.9, "width": 7.95, "height": 3.2},
        "sets_contained_in": ["10698", "10717"],
        "category": "Plates",
    },
}

SET_DB = {
    "10698": {
        "set_id": "10698",
        "name": "Classic Creative Brick Box",
        "year": 2023,
        "pieces": 790,
        "minifigures": 0,
        "age_range": "4+",
        "theme": "Classic",
        "price_usd": 49.99,
        "weight_kg": 1.2,
        "dimensions_cm": {"length": 26.2, "width": 14.1, "height": 7.1},
        "bricks_included": [
            {"id": "3001", "quantity": 12, "color": "Red"},
            {"id": "3001", "quantity": 8, "color": "Blue"},
            {"id": "3003", "quantity": 10, "color": "Yellow"},
            {"id": "3023", "quantity": 15, "color": "Green"},
        ],
        "build_time_minutes": 120,
        "difficulty": "Beginner",
        "description": "A creative brick box with ideas for multiple builds.",
    },
    "31134": {
        "set_id": "31134",
        "name": "Space Rocket",
        "year": 2023,
        "pieces": 837,
        "minifigures": 0,
        "age_range": "7+",
        "theme": "Space",
        "price_usd": 59.99,
        "bricks_included": [
            {"id": "3001", "quantity": 15, "color": "White"},
            {"id": "3004", "quantity": 8, "color": "Blue"},
            {"id": "3622", "quantity": 6, "color": "Red"},
        ],
        "build_time_minutes": 180,
        "difficulty": "Intermediate",
        "description": "Build your own space rocket with detailed features.",
    },
}

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

def handle_errors(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except FileNotFoundError as e:
            logger.error(f"File error: {e}")
            return jsonify({"success": False, "error": "File not found", "details": str(e)}), 404
        except ValueError as e:
            logger.error(f"Validation error: {e}")
            return jsonify({"success": False, "error": "Invalid input", "details": str(e)}), 400
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return jsonify({"success": False, "error": "Internal server error", "details": str(e)}), 500
    return decorated

def aggregate_bricks(raw_results):
    """Group detections by brick type and color"""
    groups = {}
    for det in raw_results:
        key = f"{det['name']}_{det['color']}"
        if key in groups:
            groups[key]["quantity"] += 1
            groups[key]["confidence"] = max(groups[key]["confidence"], det["confidence"])
        else:
            groups[key] = det.copy()
    return list(groups.values())

# ---------------------------------------------------------------------------
# API Routes
# ---------------------------------------------------------------------------

@app.route("/")
def home():
    return jsonify({
        "message": "Lego Brick Counter API",
        "version": "3.0.0",
        "detector": "Azure Custom Vision" if detector else "Not Available",
        "endpoints": {
            "/api/health": "Health check",
            "/api/upload": "Upload image for detection",
            "/api/analyze-photo": "Detailed photo analysis",
            "/api/similar": "Find similar bricks",
            "/api/inventory": "Manage inventory",
            "/api/recommendations": "Get set recommendations",
            "/api/brick/{id}": "Get brick metadata",
            "/api/set/{id}": "Get set metadata",
        },
    })

@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy" if detector else "degraded",
        "version": "3.0.0",
        "detector": "Azure Custom Vision" if detector else "Not Available",
        "pinecone": "connected" if pinecone_svc.enabled else "not_configured",
        "timestamp": _now_iso(),
    })

@app.route("/api/upload", methods=["POST"])
@handle_errors
def upload():
    """Upload image for brick detection"""
    if not detector:
        return jsonify({"success": False, "error": "Detector not available"}), 503

    # Handle file upload
    if "file" in request.files:
        file = request.files["file"]
        if file.filename == "":
            return jsonify({"success": False, "error": "No file selected"}), 400
        if not allowed_file(file.filename):
            return jsonify({"success": False, "error": "Invalid file type"}), 415

        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        fname = f"lego_{ts}_{secure_filename(file.filename)}"
        fpath = os.path.join(app.config["UPLOAD_FOLDER"], fname)
        file.save(fpath)

    # Handle base64 upload
    elif request.json and "image" in request.json:
        img_data = request.json["image"]
        if "," in img_data:
            img_data = img_data.split(",")[1]
        img_bytes = base64.b64decode(img_data)
        img = Image.open(io.BytesIO(img_bytes))
        ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        fname = f"lego_{ts}.jpg"
        fpath = os.path.join(app.config["UPLOAD_FOLDER"], fname)
        img.save(fpath)

    else:
        return jsonify({"success": False, "error": "No file or image data provided"}), 400

    # Run detection
    logger.info(f"Processing: {fpath}")
    results = detector.detect_bricks(fpath)
    aggregated = aggregate_bricks(results)

    return jsonify({
        "success": True,
        "filename": fname,
        "bricks_detected": len(aggregated),
        "results": aggregated,
        "detector": "Azure Custom Vision",
        "timestamp": _now_iso(),
    })

@app.route("/api/analyze-photo", methods=["POST"])
@handle_errors
def analyze_photo():
    """Enhanced photo analysis with metadata"""
    if not detector:
        return jsonify({"success": False, "error": "Detector not available"}), 503

    if "file" not in request.files:
        return jsonify({"success": False, "error": "No file provided"}), 400

    file = request.files["file"]
    if file.filename == "" or not allowed_file(file.filename):
        return jsonify({"success": False, "error": "Invalid file"}), 400

    start_time = time.time()
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    fname = f"analysis_{ts}_{secure_filename(file.filename)}"
    fpath = os.path.join(app.config["UPLOAD_FOLDER"], fname)
    file.save(fpath)

    # Get metadata
    img = Image.open(fpath)
    metadata = {
        "dimensions": {"width": img.width, "height": img.height},
        "format": img.format,
        "size_kb": round(os.path.getsize(fpath) / 1024, 2),
    }

    # Run detection
    det_start = time.time()
    results = detector.detect_bricks(fpath)
    det_time = (time.time() - det_start) * 1000

    # Aggregate
    aggregated = aggregate_bricks(results)

    # Statistics
    color_dist = {}
    for brick in aggregated:
        color = brick.get("color", "Unknown")
        color_dist[color] = color_dist.get(color, 0) + brick.get("quantity", 1)

    total_time = (time.time() - start_time) * 1000

    return jsonify({
        "success": True,
        "analysis_id": f"ana_{ts}",
        "image_metadata": metadata,
        "detection_summary": {
            "total_bricks": sum(b.get("quantity", 1) for b in aggregated),
            "unique_types": len(aggregated),
            "detection_time_ms": round(det_time, 2),
            "total_time_ms": round(total_time, 2),
        },
        "bricks": aggregated,
        "color_distribution": color_dist,
        "detector": "Azure Custom Vision",
        "timestamp": _now_iso(),
    })

@app.route("/api/similar", methods=["POST"])
@handle_errors
def find_similar():
    """Find similar bricks using Pinecone"""
    if not pinecone_svc.enabled:
        return jsonify({"success": False, "error": "Pinecone not configured"}), 503

    data = request.json or {}
    brick = data.get("brick")
    if not brick:
        return jsonify({"success": False, "error": "Provide 'brick' object"}), 400

    results = pinecone_svc.find_similar_bricks(brick, top_k=10)
    return jsonify({"success": True, "similar_bricks": results, "count": len(results)})

@app.route("/api/inventory", methods=["GET", "POST", "PUT", "DELETE"])
@handle_errors
def manage_inventory():
    """Inventory management"""
    user_id = request.headers.get("X-User-Id", "default_user")

    if request.method == "GET":
        if pinecone_svc.enabled:
            items = pinecone_svc.get_inventory(user_id)
            if items:
                return jsonify({
                    "success": True,
                    "count": len(items),
                    "inventory": items,
                    "source": "pinecone",
                })
        # Fallback mock data
        return jsonify({"success": True, "inventory": [], "source": "local"})

    if request.method == "POST":
        data = request.json or {}
        bricks = data.get("bricks", [])
        synced = pinecone_svc.save_inventory(user_id, bricks) if pinecone_svc.enabled else False
        return jsonify({
            "success": True,
            "message": f"Added {len(bricks)} brick(s)",
            "pinecone_synced": synced,
        })

    if request.method == "DELETE":
        if pinecone_svc.enabled:
            pinecone_svc.clear_inventory(user_id)
        return jsonify({"success": True, "message": "Inventory cleared"})

    return jsonify({"success": False, "error": "Method not supported"}), 405

@app.route("/api/recommendations", methods=["GET"])
@handle_errors
def recommendations():
    """Get LEGO set recommendations"""
    limit = min(request.args.get("limit", 5, type=int), 20)
    
    if pinecone_svc.enabled:
        user_id = request.headers.get("X-User-Id", "default_user")
        inv = pinecone_svc.get_inventory(user_id)
        if inv:
            recs = pinecone_svc.recommend_sets(inv, top_k=limit)
            if recs:
                return jsonify({"recommendations": recs, "source": "pinecone"})
    
    # Fallback
    fallback = [
        {"set_id": "10698", "name": "Classic Creative Brick Box", "completion_percentage": 85},
        {"set_id": "31134", "name": "Space Rocket", "completion_percentage": 72},
    ]
    return jsonify({"recommendations": fallback[:limit], "source": "local"})

@app.route("/api/brick/<brick_id>", methods=["GET"])
@handle_errors
def brick_metadata(brick_id):
    """Get brick metadata"""
    if brick_id in BRICK_DB:
        return jsonify({"success": True, "brick": BRICK_DB[brick_id]})
    return jsonify({"success": False, "error": f"Brick '{brick_id}' not found"}), 404

@app.route("/api/set/<set_id>", methods=["GET"])
@handle_errors
def set_metadata(set_id):
    """Get set metadata"""
    if set_id in SET_DB:
        return jsonify({"success": True, "set": SET_DB[set_id]})
    return jsonify({"success": False, "error": f"Set '{set_id}' not found"}), 404

@app.route("/api/pinecone/stats", methods=["GET"])
@handle_errors
def pinecone_stats():
    """Get Pinecone statistics"""
    stats = pinecone_svc.get_stats()
    return jsonify({"success": True, "pinecone": stats})

@app.route("/api/version", methods=["GET"])
def version():
    return jsonify({
        "api_name": "Lego Brick Counter API",
        "version": "3.0.0",
        "build_date": "2026-02-26",
        "detector": "Azure Custom Vision" if detector else "Not Available",
        "pinecone": "connected" if pinecone_svc.enabled else "not_configured",
    })

# Error handlers
@app.errorhandler(413)
def too_large(e):
    return jsonify({"success": False, "error": "File too large (max 16MB)"}), 413

@app.errorhandler(404)
def not_found(e):
    return jsonify({"success": False, "error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(e):
    return jsonify({"success": False, "error": "Internal server error"}), 500

# Entrypoint
if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)

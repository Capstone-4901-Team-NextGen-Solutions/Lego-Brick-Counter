# app.py - Lego Brick Counter API (v3.0 - Azure + ONNX Dual Detector)

from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import os
import logging
import time
from datetime import datetime, timezone, timedelta
from functools import wraps

from typing import Optional

from werkzeug.utils import secure_filename
from PIL import Image
import base64
import io
import numpy as np

from brick_detector import BrickDetector
from pinecone_service import PineconeService
from color_detector import LegoColorClassifier

# Try to import Azure detector (optional)
try:
    from azure_detector import AzureDetector
    AZURE_AVAILABLE = True
except ImportError:
    AZURE_AVAILABLE = False

# Try to import YOLOv8 detector (optional)
try:
    from yolo_detector import YOLODetector
    yolo_detector = YOLODetector(model_path='models/best.onnx', classes_path='models/classes.txt')
    logger = logging.getLogger(__name__)
    logger.info("✅ YOLOv8 detector initialized")
except Exception as e:
    yolo_detector = None
    logger = logging.getLogger(__name__)
    logger.warning(f"⚠️ YOLOv8 detector not available: {e}")

# Load environment variables FIRST
load_dotenv()

# Try to import Gemini detector (optional)
try:
    from gemini_detector import GeminiDetector
    gemini_detector = GeminiDetector()
    logger = logging.getLogger(__name__)
    logger.info(f"[Startup] Gemini detector: {'ready' if gemini_detector.loaded else 'not configured'}")
except Exception as e:
    gemini_detector = None
    logger = logging.getLogger(__name__)
    logger.warning(f"[Startup] Gemini detector failed to initialize: {e}")

# Create Flask app
app = Flask(__name__)
CORS(app)

# Configuration (reads from .env with sane defaults)
UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", "uploads")
MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", 16 * 1024 * 1024))
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp"}

app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["MAX_CONTENT_LENGTH"] = MAX_CONTENT_LENGTH

# Database configuration - add these to app.config
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///lego_app.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'your-secret-key-here')
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'jwt-secret-key')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=1)

# Initialize extensions AFTER app is created
from flask_sqlalchemy import SQLAlchemy
from flask_bcrypt import Bcrypt
from flask_login import LoginManager, UserMixin
import jwt

db = SQLAlchemy()
bcrypt = Bcrypt()
login_manager = LoginManager()

db.init_app(app)
bcrypt.init_app(app)
login_manager.init_app(app)
login_manager.login_view = 'auth_login'

# Create upload folder
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Database Models
# ---------------------------------------------------------------------------

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    is_active = db.Column(db.Boolean, default=True)
    
    # Relationships
    scan_history = db.relationship('ScanHistory', backref='user', lazy=True, cascade='all, delete-orphan')
    inventory_items = db.relationship('InventoryItem', backref='user', lazy=True, cascade='all, delete-orphan')
    favorite_sets = db.relationship('FavoriteSet', backref='user', lazy=True, cascade='all, delete-orphan')
    
    def set_password(self, password):
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')
    
    def check_password(self, password):
        return bcrypt.check_password_hash(self.password_hash, password)
    
    def generate_auth_token(self, expires_in=3600):
        return jwt.encode(
            {'user_id': self.id, 'exp': datetime.utcnow() + timedelta(seconds=expires_in)},
            app.config['JWT_SECRET_KEY'],
            algorithm='HS256'
        )
    
    @staticmethod
    def verify_auth_token(token):
        try:
            data = jwt.decode(token, app.config['JWT_SECRET_KEY'], algorithms=['HS256'])
            return User.query.get(data['user_id'])
        except:
            return None

class ScanHistory(db.Model):
    __tablename__ = 'scan_history'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    image_path = db.Column(db.String(255))
    scan_date = db.Column(db.DateTime, default=datetime.utcnow)
    total_bricks = db.Column(db.Integer, default=0)
    unique_types = db.Column(db.Integer, default=0)
    scan_results = db.Column(db.JSON)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class InventoryItem(db.Model):
    __tablename__ = 'inventory_items'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    brick_id = db.Column(db.String(50), nullable=False)
    brick_name = db.Column(db.String(100))
    color = db.Column(db.String(50))
    quantity = db.Column(db.Integer, default=1)
    last_updated = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    __table_args__ = (db.UniqueConstraint('user_id', 'brick_id', 'color', name='unique_user_brick_color'),)

class FavoriteSet(db.Model):
    __tablename__ = 'favorite_sets'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    set_id = db.Column(db.String(50), nullable=False)
    set_name = db.Column(db.String(200))
    added_date = db.Column(db.DateTime, default=datetime.utcnow)
    
    __table_args__ = (db.UniqueConstraint('user_id', 'set_id', name='unique_user_set'),)

# Create tables
with app.app_context():
    db.create_all()

# ---------------------------------------------------------------------------
# JWT Token decorator
# ---------------------------------------------------------------------------

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'success': False, 'error': 'Token is missing'}), 401
        
        try:
            if token.startswith('Bearer '):
                token = token[7:]
            current_user = User.verify_auth_token(token)
            if not current_user:
                return jsonify({'success': False, 'error': 'Invalid or expired token'}), 401
        except:
            return jsonify({'success': False, 'error': 'Invalid token'}), 401
        
        return f(current_user, *args, **kwargs)
    return decorated

# ---------------------------------------------------------------------------
# Singletons - initialised once at startup
# ---------------------------------------------------------------------------

# Detector initialization: prefer Azure Custom Vision, fallback to ONNX
detector = None
detector_type = "Not Available"

# Try Azure detector first
if AZURE_AVAILABLE:
    try:
        conf_threshold = float(os.getenv("CONFIDENCE_THRESHOLD", "0.25"))
        detector = AzureDetector(conf_threshold=conf_threshold)
        detector_type = "Azure Custom Vision"
        logger.info("Azure Custom Vision detector ready")
    except Exception as exc:
        logger.warning(f"Azure detector unavailable ({exc})")

# Fallback to ONNX detector
if detector is None:
    try:
        detector = BrickDetector(
            model_path="models/best.onnx",
            conf_threshold=0.12,
            iou_threshold=0.45,
        )
        detector_type = "ONNX"
        logger.info("ONNX Brick detector ready")
    except Exception as exc:
        logger.warning(f"ONNX Detector unavailable ({exc}) - place best.onnx in backend/models/")

# Initialize color classifier
color_classifier = LegoColorClassifier()
color_classifier.debug = True  # TODO: remove before final demo
logger.info("Color classifier initialized")

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
# Lego part-number map (extended for 50 Azure classes + legacy names)
# ---------------------------------------------------------------------------
LEGO_ID_MAP = {
    # Bricks (Azure Custom Vision classes)
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
    
    # Plates (Azure Custom Vision classes)
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
    
    # Tiles (Azure Custom Vision classes)
    'Tile 1 x 3': '63864',
    'Tile 1 x 4': '2431',
    'Tile 1 x 6': '6636',
    'Tile 1 x 8': '4162',
    'Tile 2 x 2': '3068',
    'Tile 2 x 4': '87079',
    
    # Legacy names (ONNX model class_names.txt)
    "2x4 Brick": "3001",
    "2x2 Brick": "3003",
    "1x2 Plate": "3023",
    "1x1 Brick": "3005",
    "2x6 Brick": "2456",
    "1x4 Brick": "3010",
    "1x2 Brick": "3004",
    "1x3 Brick": "3622",
    "1x6 Brick": "3009",
    "2x2 Plate": "3022",
    "2x3 Plate": "3021",
    "2x4 Plate": "3020",
    "2x4 Sloped Brick": "3039",
    "2x2 Corner Brick": "2357",
    "lego_brick": "3001",
    "brick": "3001",
}

# Static data for brick/set metadata endpoints
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

# Required-brick map used for local set suggestions
_SET_REQUIRED = {
    "10698": {"name": "Classic Creative Brick Box", "required": ["3001", "3003", "3023", "3005"], "pieces": 790, "difficulty": "beginner"},
    "31134": {"name": "Space Rocket", "required": ["3001", "3004", "3622", "2456"], "pieces": 837, "difficulty": "intermediate"},
    "10302": {"name": "Optimus Prime", "required": ["3001", "3003", "3023", "2456", "3039"], "pieces": 1508, "difficulty": "advanced"},
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _allowed(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

# Keep both names for compatibility
allowed_file = _allowed


def _map_brick_id(name: str) -> str:
    name = name.strip()
    if name in LEGO_ID_MAP:
        return LEGO_ID_MAP[name]
    lower = name.lower()
    for key, val in LEGO_ID_MAP.items():
        if key.lower() == lower:
            return val
    for key, val in LEGO_ID_MAP.items():
        if key.lower() in lower or lower in key.lower():
            return val
    return "0000"


def _aggregate(raw_detections: list) -> list:
    """Group raw per-object detections into unique brick types."""
    if not raw_detections:
        return []
    groups: dict = {}
    for det in raw_detections:
        name = det.get("name", "Unknown")
        color = det.get("color", "Unknown")
        key = f"{name}_{color}"
        if key in groups:
            groups[key]["quantity"] += 1
            groups[key]["confidence"] = max(
                groups[key]["confidence"], det.get("confidence", 0.5)
            )
        else:
            groups[key] = {
                "id": _map_brick_id(name),
                "name": name,
                "color": color,
                "quantity": 1,
                "confidence": det.get("confidence", 0.5),
                "bbox": det.get("bbox", [0, 0, 100, 100]),
            }
    return list(groups.values())

# Alias for azure-style usage
aggregate_bricks = _aggregate


def _detect_bricks(filepath: str) -> list:
    """Run detection + aggregation on a saved image file."""
    if detector is None:
        return []
    try:
        raw = detector.detect_bricks(filepath)
        
        # Add color detection to each raw detection
        for detection in raw:
            try:
                # Check if detection has bounding box information
                bbox = detection.get('bounding_box') or detection.get('bbox')
                if bbox and isinstance(bbox, dict) and all(k in bbox for k in ['left', 'top', 'width', 'height']):
                    # Use bounding box for color detection
                    color = color_classifier.detect_color_from_bbox(filepath, bbox)
                else:
                    # Fallback to full image color detection
                    color = color_classifier.detect_color_from_image(filepath)
                detection['color'] = color
            except Exception as color_exc:
                logger.warning(f"Color detection failed for brick: {color_exc}")
                detection['color'] = 'Unknown'
        
        aggregated = _aggregate(raw)
        logger.info(f"Detection: {len(raw)} raw -> {len(aggregated)} aggregated")
        return aggregated
    except Exception as exc:
        logger.error(f"Detection error: {exc}")
        return []


def _local_suggestions(bricks: list) -> list:
    """Fallback set suggestions when Pinecone is unavailable."""
    brick_ids = [b.get("id") for b in bricks]
    suggestions = []
    for sid, info in _SET_REQUIRED.items():
        req = info["required"]
        matched = [bid for bid in brick_ids if bid in req]
        pct = len(matched) / len(req) * 100 if req else 0
        if pct > 40:
            suggestions.append({
                "set_id": sid,
                "name": info["name"],
                "completion_percentage": round(pct),
                "missing_pieces": len(req) - len(matched),
                "total_pieces": info["pieces"],
                "difficulty": info["difficulty"],
                "image_url": f"https://example.com/sets/{sid}.jpg",
                "estimated_build_time": (
                    "2-3 hours" if info["difficulty"] == "beginner" else "3-5 hours"
                ),
            })
    suggestions.sort(key=lambda x: x["completion_percentage"], reverse=True)
    return suggestions


def _image_metadata(filepath: str) -> dict:
    try:
        with Image.open(filepath) as img:
            return {
                "dimensions": {"width": img.width, "height": img.height},
                "format": img.format,
                "mode": img.mode,
                "size_kb": round(os.path.getsize(filepath) / 1024, 2),
            }
    except Exception as exc:
        return {"error": str(exc)}


def handle_errors(f):
    """Unified error-handling decorator."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except FileNotFoundError as exc:
            return jsonify({"success": False, "error": "File not found", "details": str(exc)}), 404
        except ValueError as exc:
            return jsonify({"success": False, "error": "Invalid input", "details": str(exc)}), 400
        except Exception as exc:
            logger.exception("Unhandled error")
            return jsonify({"success": False, "error": "Internal server error", "details": str(exc)}), 500
    return wrapper


def _save_upload(file=None, base64_data=None) -> str:
    """Save an uploaded file or base64 payload; returns the filepath."""
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    if file is not None:
        fname = f"lego_scan_{ts}_{secure_filename(file.filename)}"
        fpath = os.path.join(UPLOAD_FOLDER, fname)
        file.save(fpath)
        return fpath

    # base64
    if "," in base64_data:
        base64_data = base64_data.split(",", 1)[1]
    img_bytes = base64.b64decode(base64_data)
    img = Image.open(io.BytesIO(img_bytes))
    fname = f"lego_scan_{ts}.jpg"
    fpath = os.path.join(UPLOAD_FOLDER, fname)
    img.save(fpath, "JPEG")
    return fpath

# ---------------------------------------------------------------------------
# AUTHENTICATION ENDPOINTS
# ---------------------------------------------------------------------------

@app.route('/api/auth/register', methods=['POST'])
def auth_register():
    """Register a new user"""
    data = request.json
    
    if not data or not data.get('email') or not data.get('password'):
        return jsonify({'success': False, 'error': 'Email and password required'}), 400
    
    # Check if user exists
    if User.query.filter_by(email=data['email']).first():
        return jsonify({'success': False, 'error': 'Email already registered'}), 400
    
    # Create new user
    username = data.get('username', data['email'].split('@')[0])
    if User.query.filter_by(username=username).first():
        username = f"{username}_{datetime.utcnow().timestamp()}"
    
    user = User(
        username=username,
        email=data['email']
    )
    user.set_password(data['password'])
    
    db.session.add(user)
    db.session.commit()
    
    # Generate token
    token = user.generate_auth_token()
    
    return jsonify({
        'success': True,
        'message': 'User created successfully',
        'token': token,
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'created_at': user.created_at.isoformat()
        }
    }), 201

@app.route('/api/auth/login', methods=['POST'])
def auth_login():
    """Login user"""
    data = request.json
    
    if not data or not data.get('email') or not data.get('password'):
        return jsonify({'success': False, 'error': 'Email and password required'}), 400
    
    # Find user
    user = User.query.filter_by(email=data['email']).first()
    
    if not user or not user.check_password(data['password']):
        return jsonify({'success': False, 'error': 'Invalid email or password'}), 401
    
    # Update last login
    user.last_login = datetime.utcnow()
    db.session.commit()
    
    # Generate token
    token = user.generate_auth_token()
    
    return jsonify({
        'success': True,
        'message': 'Login successful',
        'token': token,
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'created_at': user.created_at.isoformat(),
            'last_login': user.last_login.isoformat() if user.last_login else None
        }
    })

@app.route('/api/auth/profile', methods=['GET'])
@token_required
def auth_profile(current_user):
    """Get current user profile"""
    return jsonify({
        'success': True,
        'user': {
            'id': current_user.id,
            'username': current_user.username,
            'email': current_user.email,
            'created_at': current_user.created_at.isoformat(),
            'last_login': current_user.last_login.isoformat() if current_user.last_login else None,
            'stats': {
                'total_scans': ScanHistory.query.filter_by(user_id=current_user.id).count(),
                'total_inventory_items': InventoryItem.query.filter_by(user_id=current_user.id).count(),
                'favorite_sets': FavoriteSet.query.filter_by(user_id=current_user.id).count()
            }
        }
    })

@app.route('/api/auth/logout', methods=['POST'])
@token_required
def auth_logout(current_user):
    """Logout user (client-side token discard)"""
    return jsonify({'success': True, 'message': 'Logged out successfully'})

@app.route('/api/auth/change-password', methods=['POST'])
@token_required
def auth_change_password(current_user):
    """Change user password"""
    data = request.json
    
    if not data.get('current_password') or not data.get('new_password'):
        return jsonify({'success': False, 'error': 'Current and new password required'}), 400
    
    if not current_user.check_password(data['current_password']):
        return jsonify({'success': False, 'error': 'Current password is incorrect'}), 401
    
    current_user.set_password(data['new_password'])
    db.session.commit()
    
    return jsonify({'success': True, 'message': 'Password updated successfully'})

# ---------------------------------------------------------------------------
# UPDATED INVENTORY ENDPOINTS (with authentication)
# ---------------------------------------------------------------------------

@app.route("/api/inventory", methods=["GET"])
@token_required
def get_inventory(current_user):
    """Get user's inventory"""
    
    # Get from database
    items = InventoryItem.query.filter_by(user_id=current_user.id).all()
    
    if items:
        inventory = [{
            "id": item.brick_id,
            "name": item.brick_name,
            "color": item.color,
            "quantity": item.quantity,
            "last_updated": item.last_updated.isoformat()
        } for item in items]
        
        return jsonify({
            "success": True,
            "count": len(inventory),
            "inventory": inventory,
            "source": "database",
            "summary": {
                "total_bricks": sum(i["quantity"] for i in inventory),
                "unique_colors": len({i["color"] for i in inventory}),
                "unique_types": len({i["id"] for i in inventory}),
            },
        })
    
    # Also try Pinecone as backup
    if pinecone_svc.enabled:
        items = pinecone_svc.get_inventory(str(current_user.id))
        if items:
            return jsonify({
                "success": True,
                "count": len(items),
                "inventory": items,
                "source": "pinecone",
                "summary": {
                    "total_bricks": sum(i.get("quantity", 1) for i in items),
                    "unique_colors": len({i.get("color") for i in items}),
                    "unique_types": len({i.get("brick_id") for i in items}),
                },
            })
    
    return jsonify({
        "success": True,
        "count": 0,
        "inventory": [],
        "source": "none"
    })

@app.route("/api/inventory", methods=["POST"])
@token_required
def add_to_inventory(current_user):
    """Add items to user's inventory"""
    data = request.json or {}
    bricks = data.get("bricks")
    
    if not bricks or not isinstance(bricks, list):
        return jsonify({"success": False, "error": "Provide a 'bricks' array"}), 400
    
    added = []
    for brick in bricks:
        # Check if item exists
        item = InventoryItem.query.filter_by(
            user_id=current_user.id,
            brick_id=brick.get("id"),
            color=brick.get("color", "Unknown")
        ).first()
        
        if item:
            # Update quantity
            item.quantity += brick.get("quantity", 1)
            added.append({**brick, "updated": True})
        else:
            # Create new item
            item = InventoryItem(
                user_id=current_user.id,
                brick_id=brick.get("id"),
                brick_name=brick.get("name", "Unknown"),
                color=brick.get("color", "Unknown"),
                quantity=brick.get("quantity", 1)
            )
            db.session.add(item)
            added.append(brick)
    
    db.session.commit()
    
    # Also sync to Pinecone if enabled
    if pinecone_svc.enabled:
        pinecone_svc.save_inventory(str(current_user.id), bricks)
    
    return jsonify({
        "success": True,
        "message": f"Added {len(added)} brick(s) to inventory",
        "added": added,
        "timestamp": _now_iso(),
    })

@app.route("/api/inventory/<brick_id>", methods=["PUT"])
@token_required
def update_inventory_item(current_user, brick_id):
    """Update a specific inventory item"""
    data = request.json
    color = data.get('color', 'Unknown')
    
    item = InventoryItem.query.filter_by(
        user_id=current_user.id,
        brick_id=brick_id,
        color=color
    ).first()
    
    if not item:
        return jsonify({"success": False, "error": "Item not found"}), 404
    
    if 'quantity' in data:
        item.quantity = data['quantity']
    
    if 'name' in data:
        item.brick_name = data['name']
    
    db.session.commit()
    
    return jsonify({
        "success": True,
        "message": "Item updated",
        "item": {
            "id": item.brick_id,
            "name": item.brick_name,
            "color": item.color,
            "quantity": item.quantity
        }
    })

@app.route("/api/inventory/<brick_id>", methods=["DELETE"])
@token_required
def delete_inventory_item(current_user, brick_id):
    """Delete an inventory item"""
    color = request.args.get('color', 'Unknown')
    
    item = InventoryItem.query.filter_by(
        user_id=current_user.id,
        brick_id=brick_id,
        color=color
    ).first()
    
    if not item:
        return jsonify({"success": False, "error": "Item not found"}), 404
    
    db.session.delete(item)
    db.session.commit()
    
    return jsonify({"success": True, "message": "Item deleted"})

# ---------------------------------------------------------------------------
# SCAN HISTORY ENDPOINTS
# ---------------------------------------------------------------------------

@app.route("/api/scan-history", methods=["GET"])
@token_required
def get_scan_history(current_user):
    """Get user's scan history"""
    limit = min(request.args.get("limit", 20, type=int), 100)
    
    scans = ScanHistory.query.filter_by(user_id=current_user.id)\
        .order_by(ScanHistory.scan_date.desc())\
        .limit(limit)\
        .all()
    
    return jsonify({
        "success": True,
        "count": len(scans),
        "scans": [{
            "id": scan.id,
            "date": scan.scan_date.isoformat(),
            "image_path": scan.image_path,
            "total_bricks": scan.total_bricks,
            "unique_types": scan.unique_types,
            "results": scan.scan_results
        } for scan in scans]
    })

@app.route("/api/scan-history", methods=["DELETE"])
@token_required
def clear_scan_history(current_user):
    """Clear all scan history for current user"""
    try:
        ScanHistory.query.filter_by(user_id=current_user.id).delete()
        db.session.commit()
        return jsonify({
            "success": True,
            "message": "Scan history cleared successfully"
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({
            "success": False,
            "error": f"Failed to clear scan history: {str(e)}"
        }), 500

# ---------------------------------------------------------------------------
# UPLOAD ENDPOINT (with authentication and scan history)
# ---------------------------------------------------------------------------

@app.route("/api/upload", methods=["POST"])
@token_required
def upload_image(current_user):
    filepath: Optional[str] = None

    # Multipart file upload
    if "file" in request.files:
        f = request.files["file"]
        if not f.filename or f.filename == "":
            return jsonify({"success": False, "error": "No file selected"}), 400
        if not _allowed(f.filename):
            return jsonify({
                "success": False,
                "error": "Invalid file format",
                "details": f"Allowed: {', '.join(ALLOWED_EXTENSIONS)}",
            }), 415
        filepath = _save_upload(file=f)

    # Base64 JSON upload
    elif request.is_json and "image" in (request.json or {}):
        try:
            filepath = _save_upload(base64_data=request.json["image"])
        except Exception as exc:
            return jsonify({"success": False, "error": "Invalid base64 image", "details": str(exc)}), 400

    else:
        return jsonify({"success": False, "error": "No file or image data provided"}), 400

    # Detect
    bricks = _detect_bricks(filepath)

    # Save to scan history
    if bricks:
        scan = ScanHistory(
            user_id=current_user.id,
            image_path=filepath,
            total_bricks=len(bricks),
            unique_types=len(set(b.get("id") for b in bricks)),
            scan_results=bricks
        )
        db.session.add(scan)
        db.session.commit()

    # Persist to Pinecone
    if bricks and pinecone_svc.enabled:
        pinecone_svc.upsert_bricks(bricks)

    return jsonify({
        "success": True,
        "filename": os.path.basename(filepath),
        "bricks_detected": len(bricks),
        "results": bricks,
        "detector": detector_type,
        "pinecone_synced": pinecone_svc.enabled,
        "timestamp": _now_iso(),
    })

@app.route("/api/detect/onnx", methods=["POST"])
@token_required
def detect_with_onnx(current_user):
    """Detect bricks using local ONNX YOLOv8 model"""
    try:
        # Check detector is loaded
        if detector is None:
            return jsonify({
                'success': False,
                'error': 'ONNX model not loaded. Check that best.onnx exists in the backend/models folder.',
                'detector_used': 'ONNX YOLOv8'
            }), 503

        # Get uploaded file — same pattern as /api/upload
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'No file provided'}), 400

        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'No file selected'}), 400

        if not _allowed(file.filename):
            return jsonify({'success': False, 'error': 'File type not allowed'}), 400

        # Save file
        timestamp = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')
        filename = f"onnx_scan_{timestamp}_{secure_filename(file.filename)}"
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        file.save(filepath)
        logger.info(f"[ONNX] File saved: {filepath}")

        # Run ONNX detection
        logger.info(f"[ONNX] Running detection on: {filepath}")
        raw_results = detector.detect_bricks(filepath)
        logger.info(f"[ONNX DEBUG] raw_results type: {type(raw_results)}")
        logger.info(f"[ONNX DEBUG] raw_results count: {len(raw_results)}")
        if raw_results:
            logger.info(f"[ONNX DEBUG] first item type: {type(raw_results[0])}")
            logger.info(f"[ONNX DEBUG] first item: {raw_results[0]}")

        # Get image dimensions for bbox normalization
        from PIL import Image as PILImage
        img = PILImage.open(filepath)
        img_w, img_h = img.size
        logger.info(f"[ONNX] Image dimensions: {img_w}x{img_h}")

        # Parse results - detect_bricks returns list of dicts with:
        # {'id': str, 'name': str, 'color': str, 'quantity': int, 'confidence': float, 'bbox': [x, y, w, h]}
        results = []
        for r in raw_results:
            # Extract bbox in [x, y, width, height] pixel format
            raw_bbox = r.get('bbox', [])
            
            # Normalize bbox for color classifier (expects 0-1 range with left, top, width, height)
            if isinstance(raw_bbox, (list, tuple)) and len(raw_bbox) >= 4:
                normalized_bbox = {
                    'left': raw_bbox[0] / img_w,
                    'top': raw_bbox[1] / img_h,
                    'width': raw_bbox[2] / img_w,
                    'height': raw_bbox[3] / img_h,
                }
                logger.info(f"[ONNX] Normalized bbox: {normalized_bbox}")
                color = color_classifier.detect_color_from_bbox(filepath, normalized_bbox)
            else:
                logger.warning(f"[ONNX] Invalid bbox format: {raw_bbox}, using full image for color")
                color = color_classifier.detect_color_from_image(filepath)

            results.append({
                'brick_name': r.get('name', 'Unknown'),
                'brick_id': r.get('id', '0000'),
                'confidence': float(r.get('confidence', 0)),
                'color': color,
                'count': int(r.get('quantity', 1)),
                'quantity': int(r.get('quantity', 1)),
                'bounding_box': {
                    'left': raw_bbox[0] / img_w if len(raw_bbox) >= 4 else 0,
                    'top': raw_bbox[1] / img_h if len(raw_bbox) >= 4 else 0,
                    'width': raw_bbox[2] / img_w if len(raw_bbox) >= 4 else 0,
                    'height': raw_bbox[3] / img_h if len(raw_bbox) >= 4 else 0,
                }
            })
            logger.info(f"[ONNX] Processed brick: {results[-1]['brick_name']} - {results[-1]['color']}")

        total_bricks = sum(r['count'] for r in results)
        unique_types = len(set(r['brick_name'] for r in results))

        # Save to scan history — same pattern as /api/upload
        try:
            new_scan = ScanHistory(
                user_id=current_user.id,
                image_path=filepath,
                total_bricks=total_bricks,
                unique_types=unique_types,
                scan_results=results
            )
            db.session.add(new_scan)
            db.session.commit()
            logger.info(f"[ONNX] Scan saved to history, id={new_scan.id}")
        except Exception as db_err:
            logger.warning(f"[ONNX] Could not save scan history: {db_err}")
            db.session.rollback()

        return jsonify({
            'success': True,
            'total_bricks': total_bricks,
            'unique_types': unique_types,
            'detector_used': 'ONNX YOLOv8',
            'results': results,
            'timestamp': _now_iso(),
        })

    except Exception as e:
        logger.error(f"[ONNX] Detection error: {str(e)}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'success': False,
            'error': f'ONNX detection failed: {str(e)}',
            'detector_used': 'ONNX YOLOv8'
        }), 500


@app.route('/api/detect/gemini', methods=['POST'])
@token_required
def detect_with_gemini(current_user):
    """Detect LEGO bricks using Google Gemini Flash multimodal model"""
    try:
        # Check detector is ready
        if gemini_detector is None or not gemini_detector.loaded:
            return jsonify({
                'success': False,
                'error': 'Gemini detector not configured. Add GEMINI_API_KEY to .env file.',
                'detector_used': 'Gemini Flash'
            }), 503

        # Get uploaded file — same pattern as /api/upload
        if 'file' not in request.files:
            return jsonify({'success': False, 'error': 'No file provided'}), 400
        file = request.files['file']
        if file.filename == '':
            return jsonify({'success': False, 'error': 'No file selected'}), 400
        if not _allowed(file.filename):
            return jsonify({'success': False, 'error': 'File type not allowed'}), 400

        # Save file
        timestamp = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')
        filename = f"gemini_scan_{timestamp}_{secure_filename(file.filename)}"
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        file.save(filepath)
        logger.info(f'[Gemini] File saved: {filepath}')

        # Run Gemini detection
        raw_results = gemini_detector.detect_bricks(filepath)
        logger.info(f'[Gemini] Raw results: {raw_results}')

        # Color detection — Gemini already returns color names
        # but run through our classifier too for consistency
        results = []
        for r in raw_results:
            gemini_color = r.get('color', 'Unknown')
            # Use Gemini's color if it returned one, otherwise use our classifier
            if gemini_color and gemini_color != 'Unknown':
                color = gemini_color
            else:
                color = color_classifier.detect_color_from_image(filepath)

            results.append({
                'brick_name':   r.get('brick_name', 'Unknown'),
                'color':        color,
                'count':        int(r.get('count', 1)),
                'confidence':   float(r.get('confidence', 0.90)),
                'bounding_box': {}
            })

        total_bricks = sum(r['count'] for r in results)
        unique_types = len(set(r['brick_name'] for r in results))

        # Save to scan history
        try:
            import json
            new_scan = ScanHistory(
                user_id=current_user.id,
                image_path=filename,
                total_bricks=total_bricks,
                unique_types=unique_types,
                scan_results=json.dumps(results)
            )
            db.session.add(new_scan)
            db.session.commit()
            logger.info(f'[Gemini] Scan saved to history id={new_scan.id}')
        except Exception as db_err:
            logger.warning(f'[Gemini] Could not save scan history: {db_err}')
            db.session.rollback()

        return jsonify({
            'success':       True,
            'total_bricks':  total_bricks,
            'unique_types':  unique_types,
            'detector_used': 'Gemini Flash',
            'results':       results
        })

    except Exception as e:
        logger.error(f'[Gemini] Detection error: {str(e)}')
        import traceback
        traceback.print_exc()
        
        error_msg = str(e)
        # Give user-friendly message for quota errors
        if '429' in error_msg or 'quota' in error_msg.lower() or 'RESOURCE_EXHAUSTED' in error_msg:
            friendly = 'Gemini free tier quota exceeded for all available models. Try again in a few minutes or create a new Google Cloud project at console.cloud.google.com/projectcreate and generate a fresh API key.'
        else:
            friendly = f'Gemini detection failed: {error_msg}'
        
        return jsonify({
            'success': False,
            'error': friendly,
            'detector_used': 'Gemini Flash'
        }), 500

# ---------------------------------------------------------------------------
# ENDPOINTS 
# ---------------------------------------------------------------------------

@app.route("/")
def home():
    return jsonify({
        "message": "Lego Brick Counter API",
        "version": "3.0.0",
        "detector": detector_type,
        "pinecone_enabled": pinecone_svc.enabled,
        "endpoints": {
            "auth": {
                "register": "/api/auth/register",
                "login": "/api/auth/login",
                "profile": "/api/auth/profile",
                "logout": "/api/auth/logout",
                "change-password": "/api/auth/change-password"
            },
            "upload": "/api/upload",
            "analyze-photo": "/api/analyze-photo",
            "health": "/api/health",
            "inventory": "/api/inventory",
            "recommendations": "/api/recommendations",
            "scan-history": "/api/scan-history",
            "similar": "/api/similar",
            "brick": "/api/brick/<brick_id>",
            "set": "/api/set/<set_id>",
            "pinecone-stats": "/api/pinecone/stats",
            "version": "/api/version",
        },
    })


@app.route("/api/health", methods=["GET"])
def health():
    return jsonify({
        "status": "healthy" if detector else "degraded",
        "version": "3.0.0",
        "timestamp": _now_iso(),
        "detector": detector_type,
        "detector_status": "initialized" if detector else "not_available",
        "pinecone_status": "connected" if pinecone_svc.enabled else "not_configured",
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
    if file.filename == "" or not _allowed(file.filename):
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
    aggregated = _aggregate(results)

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
        "detector": detector_type,
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
        "build_date": "2026-03-24",
        "detector": detector_type,
        "pinecone": "connected" if pinecone_svc.enabled else "not_configured",
    })

# ---------------------------------------------------------------------------
# YOLOv8 Live Detection Endpoints
# ---------------------------------------------------------------------------

@app.route('/api/detect/yolo', methods=['POST'])
@token_required
def detect_bricks_yolo(current_user):
    """Detect LEGO bricks using YOLOv8 ONNX model — for live detection."""
    if yolo_detector is None:
        return jsonify({"error": "YOLOv8 model not loaded"}), 503
    
    if 'image' not in request.files:
        # Also accept raw bytes in request body for live camera frames
        image_bytes = request.get_data()
        if not image_bytes:
            return jsonify({"error": "No image provided"}), 400
    else:
        image_bytes = request.files['image'].read()
    
    try:
        results = yolo_detector.detect(image_bytes)
        return jsonify({
            "success": True,
            "model": "yolov8s-lego-v1",
            "total_bricks": results["total_bricks"],
            "brick_counts": results["brick_counts"],
            "detections": results["detections"]
        })
    except Exception as e:
        logger.error(f"YOLOv8 detection error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/detect/yolo/health', methods=['GET'])
def yolo_health():
    """Check if YOLOv8 model is loaded and ready."""
    return jsonify({
        "available": yolo_detector is not None,
        "model": "yolov8s-lego-v1",
        "classes": yolo_detector.class_names if yolo_detector else []
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

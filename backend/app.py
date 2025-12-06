from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import cv2
import numpy as np
import base64
import io
from PIL import Image
import os
from datetime import datetime
import logging
from brick_detector import BrickDetector
import json
import time
from werkzeug.utils import secure_filename
from functools import wraps

#Initializes Flask app
app = Flask(__name__)
CORS(app)  #Enable CORS for all routes

#Configuration
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
app.config['ALLOWED_EXTENSIONS'] = {'png', 'jpg', 'jpeg', 'gif'}

#Creates upload directory if it doesn't exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

#Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize ONNX detector once at startup
try:
    detector = BrickDetector(
        model_path='best.onnx',
        conf_threshold=0.25,
        iou_threshold=0.45
    )
    logger.info("✅ Brick detector initialized successfully")
except Exception as e:
    logger.error(f"❌ Error initializing detector: {e}")
    logger.warning("⚠️  API will run without detector - place best.onnx in backend/")
    detector = None

def allowed_file(filename):
    """Check if the file extension is allowed"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def process_image_for_bricks(image_path):
    """
    Process image using ONNX YOLOv8 model for brick detection
    """
    if detector is None:
        logger.error("Detector not initialized - model file missing")
        return []
    
    try:
        # Get raw detections from detector
        raw_results = detector.detect_bricks(image_path)
        logger.info(f"Raw detections: {len(raw_results)} objects")
        
        # Group by brick type and color for accurate counting
        aggregated_results = aggregate_brick_detections(raw_results)
        
        logger.info(f"Aggregated: {len(aggregated_results)} unique brick types")
        return aggregated_results
        
    except Exception as e:
        logger.error(f"Detection error: {str(e)}")
        return []

def aggregate_brick_detections(raw_detections):
    """
    Aggregate multiple detections of the same brick type
    Also map to Lego part numbers
    """
    if not raw_detections:
        return []
    
    #Group by brick name and color
    brick_groups = {}
    
    for detection in raw_detections:
        brick_name = detection.get('name', 'Unknown')
        color = detection.get('color', 'Unknown')
        
        #Create a unique key
        key = f"{brick_name}_{color}"
        
        if key in brick_groups:
            #Increment quantity
            brick_groups[key]['quantity'] += 1
            #Update confidence (use highest)
            brick_groups[key]['confidence'] = max(
                brick_groups[key]['confidence'], 
                detection.get('confidence', 0.5)
            )
        else:
            #Map to Lego part numbers
            brick_id = map_brick_to_lego_id(brick_name)
            
            brick_groups[key] = {
                'id': brick_id,
                'name': brick_name,
                'color': color,
                'quantity': 1,
                'confidence': detection.get('confidence', 0.5),
                'bbox': detection.get('bbox', [0, 0, 100, 100])
            }
    
    return list(brick_groups.values())

def handle_errors(f): #added error handler
    @wraps(f)
    def decorated_function(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except FileNotFoundError as e:
            logger.error(f"File error: {str(e)}")
            return jsonify({"error": "File not found", "details": str(e)}), 404
        except ValueError as e:
            logger.error(f"Validation error: {str(e)}")
            return jsonify({"error": "Invalid input", "details": str(e)}), 400
        except Exception as e:
            logger.error(f"Unexpected error: {str(e)}")
            return jsonify({"error": "Internal server error", "details": str(e)}), 500
    return decorated_function

def map_brick_to_lego_id(brick_name):
    """
    Map detected brick names to official Lego part numbers
    This should match your class_names.txt exactly
    """
    # Clean the brick name
    brick_name = brick_name.strip()
    
    # Complete Lego part number mapping
    lego_id_map = {
        #Basic bricks
        '2x4 Brick': '3001',
        '2x2 Brick': '3003',
        '1x2 Plate': '3023',
        '1x1 Brick': '3005',
        '2x6 Brick': '2456',
        '1x4 Brick': '3010',
        
        #More bricks
        '1x2 Brick': '3004',
        '1x3 Brick': '3622',
        '1x6 Brick': '3009',
        '2x2 Plate': '3022',
        '2x3 Plate': '3021',
        '2x4 Plate': '3020',
        
        #Special bricks
        '2x4 Sloped Brick': '3039',
        '2x2 Corner Brick': '2357',
        
        #Default fallbacks
        'lego_brick': '3001',  #Generic brick
        'Unknown': '0000',
        'brick': '3001',
    }
    
    if brick_name in lego_id_map:
        return lego_id_map[brick_name]
    
    #case-insensitive match
    brick_name_lower = brick_name.lower()
    for key, value in lego_id_map.items():
        if key.lower() == brick_name_lower:
            return value
    
    #partial match
    for key, value in lego_id_map.items():
        if key.lower() in brick_name_lower or brick_name_lower in key.lower():
            return value
    
    return '0000'  #Unknown brick

@app.route('/')
def home():
    """Home endpoint"""
    return jsonify({
        "message": "Lego Brick Counter API",
        "version": "1.0.0",
        "endpoints": {
            "upload": "/api/upload",
            "health": "/api/health"
        }
    })

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "timestamp": datetime.utcnow().isoformat()})

@app.route('/api/upload', methods=['POST'])
def upload_image():
        """
        Endpoint for uploading images for brick analysis
        Accepts both file uploads and base64 encoded images
        """
        try:
            #Check if request contains files
            if 'file' in request.files:
                file = request.files['file']
                
                if file.filename == '':
                    return jsonify({"error": "No file selected"}), 400
                
                if file and allowed_file(file.filename):
                    #Save the file
                    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
                    filename = f"lego_scan_{timestamp}_{file.filename}"
                    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                    file.save(filepath)
                    
                    logger.info(f"File saved: {filepath}")
                    
                    #Process the image
                    results = process_image_for_bricks(filepath)
                    
                    return jsonify({
                        "success": True,
                        "filename": filename,
                        "bricks_detected": len(results),
                        "results": results,
                        "timestamp": datetime.utcnow().isoformat()
                    })
            
            #Check for base64 encoded image
            elif 'image' in request.json:
                image_data = request.json['image']
                
                #Remove data URL prefix if present
                if ',' in image_data:
                    image_data = image_data.split(',')[1]
                
                #Decode base64 image
                image_bytes = base64.b64decode(image_data)
                image = Image.open(io.BytesIO(image_bytes))
                
                #Save the image
                timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
                filename = f"lego_scan_{timestamp}.jpg"
                filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                image.save(filepath)
                
                logger.info(f"Base64 image saved: {filepath}")
                
                #Process the image
                results = process_image_for_bricks(filepath)
                
                return jsonify({
                    "success": True,
                    "filename": filename,
                    "bricks_detected": len(results),
                    "results": results,
                    "timestamp": datetime.utcnow().isoformat()
                })
            
            else:
                return jsonify({"error": "No file or image data provided"}), 400
                
        except Exception as e:
            logger.error(f"Error processing image: {str(e)}")
            return jsonify({"error": f"Processing failed: {str(e)}"}), 500

@app.route('/api/analyze/color', methods=['POST'])
def analyze_color():
    """Analyze color detection for debugging"""
    try:
        if 'file' not in request.files:
            return jsonify({"error": "No file provided"}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({"error": "No file selected"}), 400
        
        #Save file
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], "color_analysis.jpg")
        file.save(filepath)
        
        #Load image
        img = cv2.imread(filepath)
        
        #Let user specify coordinates or analyze whole image
        data = request.form
        if 'x' in data and 'y' in data and 'w' in data and 'h' in data:
            x, y, w, h = map(int, [data['x'], data['y'], data['w'], data['h']])
            roi = img[y:y+h, x:x+w]
        else:
            roi = img
        
        #Analyze
        hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        rgb = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB)
        
        mean_hsv = np.mean(hsv, axis=(0, 1))
        mean_rgb = np.mean(rgb, axis=(0, 1))
        std_hsv = np.std(hsv, axis=(0, 1))
        
        if detector:
            detected_color = detector._detect_color(roi)
        else:
            detected_color = "Unknown"
        
        return jsonify({
            "detected_color": detected_color,
            "mean_hsv": {
                "h": float(mean_hsv[0]),
                "s": float(mean_hsv[1]),
                "v": float(mean_hsv[2])
            },
            "std_hsv": {
                "h": float(std_hsv[0]),
                "s": float(std_hsv[1]),
                "v": float(std_hsv[2])
            },
            "mean_rgb": {
                "r": float(mean_rgb[0]),
                "g": float(mean_rgb[1]),
                "b": float(mean_rgb[2])
            },
            "roi_size": roi.shape[:2] if roi.size > 0 else [0, 0]
        })
        
    except Exception as e:
        logger.error(f"Color analysis error: {str(e)}")
        return jsonify({"error": f"Analysis failed: {str(e)}"}), 500
    
@app.route('/api/scan/camera', methods=['POST'])
def process_camera_scan():
    """
    Endpoint specifically for camera scans
    Expects base64 image data
    """
    try:
        if not request.json or 'image' not in request.json:
            return jsonify({"error": "No image data provided"}), 400
        
        image_data = request.json['image']
        
        #Remove data URL prefix if present
        if ',' in image_data:
            image_data = image_data.split(',')[1]
        
        #Decode base64 image
        image_bytes = base64.b64decode(image_data)
        image = Image.open(io.BytesIO(image_bytes))
        
        #Convert to OpenCV format for processing
        cv_image = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
        
        #Save the image
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        filename = f"camera_scan_{timestamp}.jpg"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        cv2.imwrite(filepath, cv_image)
        
        logger.info(f"Camera scan saved: {filepath}")
        
        #Process the image (using mock function for now)
        results = process_image_for_bricks(filepath)
        
        return jsonify({
            "success": True,
            "filename": filename,
            "bricks_detected": len(results),
            "results": results,
            "timestamp": datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error processing camera scan: {str(e)}")
        return jsonify({"error": f"Camera scan failed: {str(e)}"}), 500

#Update the existing inventory endpoint
@app.route('/api/inventory', methods=['GET', 'POST', 'PUT', 'DELETE'])
@handle_errors
def manage_inventory():
    """Complete inventory management with CRUD operations"""
    if request.method == 'GET':
        #Get inventory with optional filtering
        color_filter = request.args.get('color')
        min_quantity = request.args.get('min_quantity', type=int)
        
        #TODO: Mock data - replace with database later
        mock_inventory = [
            {"id": "3001", "name": "2x4 Brick", "color": "Red", "quantity": 15, "last_updated": "2024-01-15T10:30:00Z"},
            {"id": "3003", "name": "2x2 Brick", "color": "Blue", "quantity": 12, "last_updated": "2024-01-15T10:30:00Z"},
            {"id": "3023", "name": "1x2 Plate", "color": "Yellow", "quantity": 20, "last_updated": "2024-01-15T10:30:00Z"},
            {"id": "3005", "name": "1x1 Brick", "color": "Green", "quantity": 8, "last_updated": "2024-01-15T10:30:00Z"},
            {"id": "2456", "name": "2x6 Brick", "color": "Black", "quantity": 3, "last_updated": "2024-01-15T10:30:00Z"},
        ]
        
        #Apply filters
        filtered = mock_inventory
        if color_filter:
            filtered = [item for item in filtered if item['color'].lower() == color_filter.lower()]
        if min_quantity:
            filtered = [item for item in filtered if item['quantity'] >= min_quantity]
        
        return jsonify({
            "success": True,
            "count": len(filtered),
            "inventory": filtered,
            "summary": {
                "total_bricks": sum(item['quantity'] for item in filtered),
                "unique_colors": len(set(item['color'] for item in filtered)),
                "unique_types": len(set(item['id'] for item in filtered))
            }
        })
    
    elif request.method == 'POST':
        #Add bricks to inventory
        data = request.json
        
        if not data or 'bricks' not in data:
            return jsonify({"success": False, "error": "No bricks provided"}), 400
        
        bricks = data['bricks']
        if not isinstance(bricks, list):
            return jsonify({"success": False, "error": "Bricks must be an array"}), 400
        
        #Validate each brick
        for brick in bricks:
            if not all(k in brick for k in ['id', 'name', 'quantity']):
                return jsonify({"success": False, "error": "Each brick must have id, name, and quantity"}), 400
        
        #TODO: Add to database
        added_count = len(bricks)
        
        return jsonify({
            "success": True,
            "message": f"Added {added_count} brick(s) to inventory",
            "added": bricks,
            "timestamp": datetime.utcnow().isoformat()
        })
    
    elif request.method == 'PUT':
        #pdate brick quantities
        data = request.json
        
        if not data or 'updates' not in data:
            return jsonify({"success": False, "error": "No updates provided"}), 400
        
        updates = data['updates']
        
        #TODO: Update database
        updated_count = len(updates)
        
        return jsonify({
            "success": True,
            "message": f"Updated {updated_count} brick(s)",
            "updates": updates
        })
    
    elif request.method == 'DELETE':
        #Clear entire inventory or specific bricks
        brick_ids = request.args.getlist('brick_id')
        
        if brick_ids:
            #Delete specific bricks
            deleted_count = len(brick_ids)
            return jsonify({
                "success": True,
                "message": f"Deleted {deleted_count} brick type(s) from inventory",
                "deleted_ids": brick_ids
            })
        else:
            #Clear entire inventory
            confirmation = request.args.get('confirm', '').lower() == 'true'
            
            if not confirmation:
                return jsonify({
                    "success": False,
                    "error": "Confirmation required. Add ?confirm=true to clear inventory",
                    "warning": "This will delete ALL inventory data"
                }), 400
            
            return jsonify({
                "success": True,
                "message": "Inventory cleared successfully"
            })

@app.route('/api/recommendations', methods=['GET'])
def get_recommendations():
    """Get set recommendations based on current inventory"""
    #TODO: Implement actual recommendation logic
    mock_recommendations = [
        {
            "set_id": "10698",
            "name": "Classic Creative Brick Box",
            "completion_percentage": 85,
            "missing_pieces": 12,
            "total_pieces": 790,
            "image_url": ""
        },
        {
            "set_id": "31134",
            "name": "Space Rocket",
            "completion_percentage": 72,
            "missing_pieces": 23,
            "total_pieces": 837,
            "image_url": ""
        }
    ]
    
    return jsonify({"recommendations": mock_recommendations})

@app.errorhandler(413)
def too_large(e):
    return jsonify({"error": "File too large"}), 413

@app.errorhandler(500)
def internal_error(e):
    return jsonify({"error": "Internal server error"}), 500

@app.route('/api/analyze-photo', methods=['POST'])
@handle_errors
def analyze_photo():
    """
    Enhanced photo analysis endpoint
    Returns detailed metadata and analysis
    """
    start_time = time.time()
    
    # Check if request contains file
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    file = request.files['file']
    
    # Validate file
    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400
    
    if not allowed_file(file.filename):
        return jsonify({"error": f"File type not allowed. Allowed types: {', '.join(app.config['ALLOWED_EXTENSIONS'])}"}), 415
    
    # Secure filename and save
    filename = secure_filename(file.filename)
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    unique_filename = f"analysis_{timestamp}_{filename}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], unique_filename)
    file.save(filepath)
    
    logger.info(f"Photo analysis saved: {filepath}")
    
    # Get image metadata
    try:
        with Image.open(filepath) as img:
            image_metadata = {
                "dimensions": {"width": img.width, "height": img.height},
                "format": img.format,
                "mode": img.mode,
                "size_kb": os.path.getsize(filepath) / 1024
            }
    except Exception as e:
        image_metadata = {"error": f"Could not read metadata: {str(e)}"}
    
    # Process for bricks
    if detector is None:
        return jsonify({"error": "Brick detector not available", "code": "DETECTOR_NOT_INITIALIZED"}), 503
    
    detection_start = time.time()
    bricks = process_image_for_bricks(filepath)
    detection_time = (time.time() - detection_start) * 1000  # Convert to ms
    
    # Calculate statistics
    color_distribution = {}
    unique_types = set()
    
    for brick in bricks:
        color = brick.get('color', 'Unknown')
        color_distribution[color] = color_distribution.get(color, 0) + brick.get('quantity', 1)
        unique_types.add(brick.get('id', ''))
    
    # Generate set suggestions based on bricks
    suggested_sets = suggest_sets_from_bricks(bricks)
    
    total_time = (time.time() - start_time) * 1000
    
    return jsonify({
        "success": True,
        "analysis_id": f"ana_{timestamp}",
        "image_metadata": image_metadata,
        "detection_summary": {
            "total_bricks": sum(b.get('quantity', 1) for b in bricks),
            "unique_types": len(unique_types),
            "detection_time_ms": round(detection_time, 2),
            "total_processing_time_ms": round(total_time, 2)
        },
        "bricks": bricks,
        "color_distribution": color_distribution,
        "suggested_sets": suggested_sets[:5],  # Top 5
        "timestamp": datetime.utcnow().isoformat()
    })

def suggest_sets_from_bricks(bricks):
    """
    Simple set suggestion based on detected bricks
    In production, this would query a database
    """
    # Mock data - in reality, query a Lego set database
    available_sets = {
        "10698": {
            "name": "Classic Creative Brick Box",
            "required_bricks": ["3001", "3003", "3023", "3005"],
            "total_pieces": 790,
            "difficulty": "beginner"
        },
        "31134": {
            "name": "Space Rocket",
            "required_bricks": ["3001", "3004", "3622", "2456"],
            "total_pieces": 837,
            "difficulty": "intermediate"
        },
        "10302": {
            "name": "Optimus Prime",
            "required_bricks": ["3001", "3003", "3023", "2456", "3039"],
            "total_pieces": 1508,
            "difficulty": "advanced"
        }
    }
    
    suggestions = []
    brick_ids = [b.get('id') for b in bricks]
    
    for set_id, set_info in available_sets.items():
        required = set_info['required_bricks']
        available = [bid for bid in brick_ids if bid in required]
        completion = len(available) / len(required) * 100 if required else 0
        
        if completion > 40:  # Only suggest if we have at least 40% of required bricks
            suggestions.append({
                "set_id": set_id,
                "name": set_info['name'],
                "completion_percentage": round(completion),
                "missing_pieces": len(required) - len(available),
                "total_pieces": set_info['total_pieces'],
                "difficulty": set_info['difficulty'],
                "image_url": f"https://example.com/sets/{set_id}.jpg"
            })
    
    # Sort by completion percentage
    suggestions.sort(key=lambda x: x['completion_percentage'], reverse=True)
    return suggestions

@app.route('/api/brick/<brick_id>', methods=['GET'])
@handle_errors
def get_brick_metadata(brick_id):
    """
    Get detailed metadata for a specific brick
    """
    # Mock data - in production, query a database
    brick_database = {
        "3001": {
            "official_name": "Brick 2x4",
            "alternate_names": ["2x4 Brick", "Basic Brick"],
            "colors_available": ["Red", "Blue", "Yellow", "Green", "Black", "White", "Gray"],
            "first_released": "1958",
            "weight_g": 2.32,
            "dimensions_mm": {"length": 31.8, "width": 15.9, "height": 9.6},
            "sets_contained_in": ["10698", "11011", "10717"],
            "category": "Basic Bricks",
            "material": "ABS Plastic",
            "description": "The classic 2x4 Lego brick, first produced in 1958."
        },
        "3003": {
            "official_name": "Brick 2x2",
            "alternate_names": ["2x2 Brick"],
            "colors_available": ["Red", "Blue", "Yellow", "Green", "Black", "White"],
            "first_released": "1958",
            "weight_g": 1.05,
            "dimensions_mm": {"length": 15.9, "width": 15.9, "height": 9.6},
            "sets_contained_in": ["10698", "11011"],
            "category": "Basic Bricks"
        },
        "3023": {
            "official_name": "Plate 1x2",
            "alternate_names": ["1x2 Plate"],
            "colors_available": ["Red", "Blue", "Yellow", "Green", "Black", "White", "Gray"],
            "first_released": "1963",
            "weight_g": 0.42,
            "dimensions_mm": {"length": 15.9, "width": 7.95, "height": 3.2},
            "sets_contained_in": ["10698", "10717"],
            "category": "Plates"
        }
    }
    
    if brick_id in brick_database:
        return jsonify({
            "success": True,
            "brick": brick_database[brick_id]
        })
    else:
        return jsonify({
            "success": False,
            "error": f"Brick ID {brick_id} not found"
        }), 404

@app.route('/api/set/<set_id>', methods=['GET'])
@handle_errors
def get_set_metadata(set_id):
    """
    Get detailed metadata for a Lego set
    """
    # Mock data - in production, query a database
    set_database = {
        "10698": {
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
                {"id": "3023", "quantity": 15, "color": "Green"}
            ],
            "build_time_minutes": 120,
            "difficulty": "Beginner",
            "description": "A creative brick box with ideas for multiple builds."
        }
    }
    
    if set_id in set_database:
        return jsonify({
            "success": True,
            "set": set_database[set_id]
        })
    else:
        return jsonify({
            "success": False,
            "error": f"Set ID {set_id} not found"
        }), 404

@app.route('/api/version', methods=['GET'])
def get_version():
    """Get API version information"""
    return jsonify({
        "api_name": "Lego Brick Counter API",
        "version": "1.0.0",
        "build_date": "2024-01-15",
        "endpoints": [
            "/api/health",
            "/api/upload",
            "/api/analyze-photo",
            "/api/inventory",
            "/api/recommendations",
            "/api/brick/{id}",
            "/api/set/{id}",
            "/api/version"
        ],
        "detector_status": "initialized" if detector else "not_available"
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
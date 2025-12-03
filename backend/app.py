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

@app.route('/api/inventory', methods=['GET', 'POST'])
def manage_inventory():
    """Manage user inventory"""
    if request.method == 'GET':
        #Return current inventory
        #TODO: Connect to database
        mock_inventory = [
            {"id": "3001", "name": "2x4 Brick", "color": "Red", "quantity": 15},
            {"id": "3003", "name": "2x2 Brick", "color": "Blue", "quantity": 12},
            {"id": "3023", "name": "1x2 Plate", "color": "Yellow", "quantity": 20},
        ]
        return jsonify({"inventory": mock_inventory})
    
    elif request.method == 'POST':
        #Add to inventory
        data = request.json
        #TODO: Save to database
        return jsonify({"success": True, "message": "Inventory updated"})

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

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
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

def allowed_file(filename):
    """Check if the file extension is allowed"""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in app.config['ALLOWED_EXTENSIONS']

def process_image_for_bricks(image_path):
    """
    Mock function for brick detection and classification
    Replace this with your actual CV/ML model
    """
    #TODO: Replace with actual OpenCV/ML processing
    #This is a mock implementation
    
    #Simulates processing time
    import time
    time.sleep(1)
    
    #Mock detection results
    mock_bricks = [
        {
            "id": "3001",
            "name": "2x4 Brick",
            "color": "Red",
            "quantity": 3,
            "confidence": 0.95,
            "bbox": [100, 100, 200, 150]  # x, y, w, h
        },
        {
            "id": "3003",
            "name": "2x2 Brick",
            "color": "Blue",
            "quantity": 2,
            "confidence": 0.92,
            "bbox": [300, 200, 120, 120]
        },
        {
            "id": "3023",
            "name": "1x2 Plate",
            "color": "Yellow",
            "quantity": 5,
            "confidence": 0.88,
            "bbox": [150, 300, 80, 160]
        }
    ]
    
    return mock_bricks

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
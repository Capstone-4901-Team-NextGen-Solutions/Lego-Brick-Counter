# azure_detector.py - Azure Custom Vision LEGO Brick Detector with Color Detection

import os
import cv2
import numpy as np
import logging
from typing import List, Dict
from azure.cognitiveservices.vision.customvision.prediction import CustomVisionPredictionClient
from msrest.authentication import ApiKeyCredentials

logger = logging.getLogger(__name__)


class AzureDetector:
    """
    Azure Custom Vision-based LEGO brick detector with integrated color detection.
    Drop-in replacement for BrickDetector class (same interface).
    """

    # LEGO part number mapping for 50 Azure classes
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
        
        # Legacy/fallback
        '2x4 Brick': '3001',
        '2x2 Brick': '3003',
        '1x2 Plate': '3023',
        'lego_brick': '3001',
    }

    def __init__(
        self,
        prediction_key: str = None,
        prediction_endpoint: str = None,
        project_id: str = None,
        published_name: str = None,
        conf_threshold: float = 0.25,
    ):
        """Initialize Azure Custom Vision detector"""
        # Load from environment variables if not provided
        self.prediction_key = prediction_key or os.getenv('AZURE_CV_PREDICTION_KEY')
        self.prediction_endpoint = prediction_endpoint or os.getenv('AZURE_CV_PREDICTION_ENDPOINT')
        self.project_id = project_id or os.getenv('AZURE_CV_PROJECT_ID')
        self.published_name = published_name or os.getenv('AZURE_CV_PUBLISHED_NAME', 'Iteration2')
        self.conf_threshold = conf_threshold
        
        # Validate credentials
        if not all([self.prediction_key, self.prediction_endpoint, self.project_id]):
            raise ValueError(
                "Missing Azure credentials. Set environment variables:\n"
                "  AZURE_CV_PREDICTION_KEY\n"
                "  AZURE_CV_PREDICTION_ENDPOINT\n"
                "  AZURE_CV_PROJECT_ID"
            )
        
        # Initialize Azure client
        logger.info(f"🔄 Initializing Azure Custom Vision...")
        logger.info(f"   Endpoint: {self.prediction_endpoint}")
        logger.info(f"   Project: {self.project_id}")
        logger.info(f"   Published: {self.published_name}")
        
        credentials = ApiKeyCredentials(in_headers={"Prediction-key": self.prediction_key})
        self.predictor = CustomVisionPredictionClient(self.prediction_endpoint, credentials)
        
        logger.info(f"✅ Azure detector initialized (threshold={self.conf_threshold})")

    def detect_bricks(self, image_path: str) -> List[Dict]:
        """Detect LEGO bricks using Azure Custom Vision"""
        logger.info(f"🔍 Running Azure detection on: {image_path}")
        
        # Load image
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Cannot read image: {image_path}")
        
        img_height, img_width = image.shape[:2]
        
        try:
            # Read image as bytes for Azure API
            with open(image_path, "rb") as image_file:
                image_data = image_file.read()
            
            # Call Azure Custom Vision API
            results = self.predictor.detect_image(
                self.project_id,
                self.published_name,
                image_data
            )
            
            logger.info(f"📊 Azure returned {len(results.predictions)} predictions")
            
            # Process predictions
            detections = []
            brick_counts = {}
            
            for pred in results.predictions:
                # Filter by confidence threshold
                if pred.probability < self.conf_threshold:
                    continue
                
                brick_name = pred.tag_name
                confidence = pred.probability
                bbox_norm = pred.bounding_box
                
                # Convert normalized bbox (0-1) to pixels
                x = int(bbox_norm.left * img_width)
                y = int(bbox_norm.top * img_height)
                w = int(bbox_norm.width * img_width)
                h = int(bbox_norm.height * img_height)
                
                # Ensure bbox is within image bounds
                x = max(0, min(x, img_width - 1))
                y = max(0, min(y, img_height - 1))
                w = max(1, min(w, img_width - x))
                h = max(1, min(h, img_height - y))
                
                # Count occurrences
                brick_counts[brick_name] = brick_counts.get(brick_name, 0) + 1
                
                # Extract ROI for color detection
                roi = image[y:y+h, x:x+w]
                color = self._detect_colour(roi)
                
                # Map to LEGO part number
                brick_id = self._map_to_lego_id(brick_name)
                
                detections.append({
                    "id": brick_id,
                    "name": brick_name,
                    "color": color,
                    "quantity": 1,
                    "confidence": confidence,
                    "bbox": [x, y, w, h]
                })
            
            logger.info(f"✅ Filtered to {len(detections)} detections above threshold")
            return detections
            
        except Exception as e:
            logger.error(f"❌ Azure detection failed: {str(e)}")
            raise

    def _map_to_lego_id(self, brick_name: str) -> str:
        """Map Azure tag name to LEGO part number"""
        if brick_name in self.LEGO_ID_MAP:
            return self.LEGO_ID_MAP[brick_name]
        
        brick_lower = brick_name.lower()
        for key, value in self.LEGO_ID_MAP.items():
            if key.lower() == brick_lower:
                return value
        
        for key, value in self.LEGO_ID_MAP.items():
            if key.lower() in brick_lower or brick_lower in key.lower():
                return value
        
        return '0000'

    @staticmethod
    def _detect_colour(roi: np.ndarray) -> str:
        """Detect LEGO color from ROI using HSV"""
        if roi.size == 0 or roi.shape[0] < 5 or roi.shape[1] < 5:
            return "Unknown"
        
        hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        h = float(np.mean(hsv[:, :, 0]))
        s = float(np.mean(hsv[:, :, 1]))
        v = float(np.mean(hsv[:, :, 2]))
        
        # Grayscale colors
        if s < 40:
            if v < 50:
                return "Black"
            elif v > 200:
                return "White"
            elif v > 150:
                return "Light Gray"
            else:
                return "Dark Gray"
        
        # Brown
        if s < 100 and 10 <= h <= 25 and 50 < v < 150:
            return "Brown"
        
        # Chromatic colors
        if h < 10 or h > 170:
            return "Red"
        if 10 <= h < 20:
            return "Orange"
        if 20 <= h < 35:
            return "Yellow"
        if 35 <= h < 50:
            return "Lime"
        if 50 <= h < 85:
            return "Green"
        if 85 <= h < 100:
            return "Cyan"
        if 100 <= h < 130:
            return "Blue"
        if 130 <= h < 150:
            return "Purple"
        if 150 <= h < 170:
            return "Magenta"
        
        return "Unknown"

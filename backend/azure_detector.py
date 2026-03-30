# azure_detector.py 

import os
import cv2
import numpy as np
import logging
from typing import List, Dict
from azure.cognitiveservices.vision.customvision.prediction import CustomVisionPredictionClient
from msrest.authentication import ApiKeyCredentials

# Import your color classifier
from color_detector import HSVColorClassifier

logger = logging.getLogger(__name__)


class AzureDetector:
    """Azure Custom Vision-based LEGO brick detector with improved color detection"""

    # LEGO part number mapping 
    LEGO_ID_MAP = { ... }  # Your existing mapping

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
        
        # Initialize color classifier once
        self.color_classifier = HSVColorClassifier()
        
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
                
                # Extract ROI for color detection
                roi = image[y:y+h, x:x+w]
                
                # Use the better color detection method
                color = self._detect_brick_color(roi)
                
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

    def _detect_brick_color(self, roi: np.ndarray) -> str:
        """Improved color detection with inner cropping and median filtering"""
        if roi is None or roi.size == 0 or roi.shape[0] < 5 or roi.shape[1] < 5:
            return "Unknown"
        
        # Crop inner region to avoid edges and shadows
        h, w = roi.shape[:2]
        margin_x = int(w * 0.2)  # Crop 20% from edges
        margin_y = int(h * 0.2)
        
        # Only crop if we have enough space
        if margin_x > 0 and margin_y > 0 and w > margin_x*2 and h > margin_y*2:
            roi = roi[margin_y:h-margin_y, margin_x:w-margin_x]
        
        # Use the HSVColorClassifier for better results
        return self.color_classifier.get_dominant_color(roi)

    def _map_to_lego_id(self, brick_name: str) -> str:
        """Map Azure tag name to LEGO part number"""
        # Your existing mapping logic
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
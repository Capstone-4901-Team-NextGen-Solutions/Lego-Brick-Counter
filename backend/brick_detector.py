# brick_detector.py - ONNX-based LEGO Brick Detector

import cv2
import numpy as np
import onnxruntime
import os

class BrickDetector:
    def __init__(self, model_path='best.onnx', conf_threshold=0.25, iou_threshold=0.45):
        """
        Initialize the ONNX-based brick detector
        
        Args:
            model_path: Path to ONNX model file
            conf_threshold: Confidence threshold for detections
            iou_threshold: IoU threshold for NMS
        """
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found: {model_path}")
        
        # Load ONNX model
        print(f"🔄 Loading ONNX model from: {model_path}")
        self.session = onnxruntime.InferenceSession(
            model_path,
            providers=['CPUExecutionProvider']
        )
        
        # Get model input details
        self.input_name = self.session.get_inputs()[0].name
        self.input_shape = self.session.get_inputs()[0].shape
        self.input_size = self.input_shape[2] if len(self.input_shape) > 2 else 640
        
        # Detection thresholds
        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        
        # Load class names
        self.class_names = self._load_class_names()
        
        print(f"✅ Model loaded successfully")
        print(f"   Input size: {self.input_size}x{self.input_size}")
        print(f"   Classes: {self.class_names}")
        print(f"   Confidence threshold: {self.conf_threshold}")
    
    def _load_class_names(self, class_file='class_names.txt'):
        """Load class names from file"""
        if os.path.exists(class_file):
            with open(class_file, 'r') as f:
                return [line.strip() for line in f.readlines()]
        return ['lego_brick']  # Default
    
    def detect_bricks(self, image_path):
        """
        Detect and classify Lego bricks in an image
        
        Args:
            image_path: Path to input image
            
        Returns:
            List of detection dictionaries
        """
        # Read image
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Could not read image: {image_path}")
        
        original_shape = image.shape[:2]  # (height, width)
        
        # Preprocess
        preprocessed, ratio, padding = self._preprocess_image(image)
        
        # Run inference
        outputs = self.session.run(None, {self.input_name: preprocessed})
        
        # Post-process
        detections = self._post_process(outputs[0], ratio, padding, original_shape)
        
        # Format results
        results = self._format_results(detections, image)
        
        return results
    
    def _preprocess_image(self, img):
        """
        Preprocess image for YOLO inference
        - Resize with letterboxing
        - Normalize to [0, 1]
        - Convert to CHW format
        """
        # Get original dimensions
        h, w = img.shape[:2]
        
        # Calculate scale ratio
        scale = min(self.input_size / h, self.input_size / w)
        new_h, new_w = int(h * scale), int(w * scale)
        
        # Resize image
        img_resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
        
        # Create padded image (letterboxing)
        padded_img = np.full((self.input_size, self.input_size, 3), 114, dtype=np.uint8)
        
        # Calculate padding offsets (center the image)
        pad_h = (self.input_size - new_h) // 2
        pad_w = (self.input_size - new_w) // 2
        
        # Place resized image in center
        padded_img[pad_h:pad_h+new_h, pad_w:pad_w+new_w] = img_resized
        
        # Convert BGR to RGB
        img_rgb = cv2.cvtColor(padded_img, cv2.COLOR_BGR2RGB)
        
        # Normalize to [0, 1]
        img_normalized = img_rgb.astype(np.float32) / 255.0
        
        # Transpose HWC to CHW
        img_transposed = img_normalized.transpose(2, 0, 1)
        
        # Add batch dimension
        img_batch = np.expand_dims(img_transposed, axis=0)
        
        return img_batch, scale, (pad_w, pad_h)
    
    def _post_process(self, predictions, scale, padding, original_shape):
        """
        Post-process YOLOv8 predictions
        - Extract boxes and scores
        - Apply confidence threshold
        - Apply NMS
        - Scale boxes to original image size
        """
        # Remove batch dimension and transpose
        # YOLOv8 output: [batch, 84, 8400] -> [8400, 84]
        predictions = np.squeeze(predictions).T
        
        # Extract box coordinates and scores
        boxes = predictions[:, :4]  # [x_center, y_center, width, height]
        scores = predictions[:, 4:].max(axis=1)  # Max confidence
        class_ids = predictions[:, 4:].argmax(axis=1)
        
        # Filter by confidence threshold
        mask = scores > self.conf_threshold
        boxes = boxes[mask]
        scores = scores[mask]
        class_ids = class_ids[mask]
        
        if len(boxes) == 0:
            return []
        
        # Convert from xywh to xyxy format
        boxes = self._xywh2xyxy(boxes)
        
        # Apply Non-Maximum Suppression
        indices = self._non_max_suppression(boxes, scores)
        
        if len(indices) == 0:
            return []
        
        boxes = boxes[indices]
        scores = scores[indices]
        class_ids = class_ids[indices]
        
        # Scale boxes back to original image
        boxes = self._scale_boxes(boxes, scale, padding, original_shape)
        
        # Combine into detection list
        detections = []
        for box, score, class_id in zip(boxes, scores, class_ids):
            detections.append({
                'bbox': box.tolist(),
                'confidence': float(score),
                'class_id': int(class_id),
                'class_name': self.class_names[class_id] if class_id < len(self.class_names) else 'unknown'
            })
        
        return detections
    
    def _xywh2xyxy(self, boxes):
        """Convert [x_center, y_center, w, h] to [x1, y1, x2, y2]"""
        boxes_xyxy = boxes.copy()
        boxes_xyxy[:, 0] = boxes[:, 0] - boxes[:, 2] / 2  # x1
        boxes_xyxy[:, 1] = boxes[:, 1] - boxes[:, 3] / 2  # y1
        boxes_xyxy[:, 2] = boxes[:, 0] + boxes[:, 2] / 2  # x2
        boxes_xyxy[:, 3] = boxes[:, 1] + boxes[:, 3] / 2  # y2
        return boxes_xyxy
    
    def _non_max_suppression(self, boxes, scores):
        """Apply Non-Maximum Suppression using OpenCV"""
        indices = cv2.dnn.NMSBoxes(
            boxes.tolist(),
            scores.tolist(),
            score_threshold=self.conf_threshold,
            nms_threshold=self.iou_threshold
        )
        
        if len(indices) > 0:
            return indices.flatten()
        return np.array([])
    
    def _scale_boxes(self, boxes, scale, padding, original_shape):
        """Scale boxes back to original image coordinates"""
        pad_w, pad_h = padding
        
        # Remove padding
        boxes[:, [0, 2]] -= pad_w
        boxes[:, [1, 3]] -= pad_h
        
        # Scale to original size
        boxes[:, :4] /= scale
        
        # Clip to image boundaries
        boxes[:, [0, 2]] = boxes[:, [0, 2]].clip(0, original_shape[1])
        boxes[:, [1, 3]] = boxes[:, [1, 3]].clip(0, original_shape[0])
        
        return boxes
    
    def _format_results(self, detections, image):
        """
        Format detections for API response
        Compatible with existing API format
        """
        results = []
        brick_counts = {}
        
        for det in detections:
            bbox = det['bbox']
            class_name = det['class_name']
            
            # Count bricks by class
            brick_counts[class_name] = brick_counts.get(class_name, 0) + 1
            
            # Extract color from ROI
            x1, y1, x2, y2 = map(int, bbox)
            roi = image[y1:y2, x1:x2]
            color = self._detect_color(roi)
            
            # Format as API expects
            results.append({
                "id": f"{class_name}_{brick_counts[class_name]}",
                "name": class_name,
                "color": color,
                "quantity": 1,
                "confidence": det['confidence'],
                "bbox": [x1, y1, int(x2-x1), int(y2-y1)]  # [x, y, w, h]
            })
        
        return results
    
    def _detect_color(self, roi):
        """
        Simple color detection from ROI using HSV
        """
        if roi.size == 0:
            return "Unknown"
        
        # Resize ROI if too small
        if roi.shape[0] < 10 or roi.shape[1] < 10:
            return "Unknown"
        
        # Convert to HSV
        hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        
        # Get mean hue value
        mean_hue = np.mean(hsv[:, :, 0])
        mean_sat = np.mean(hsv[:, :, 1])
        mean_val = np.mean(hsv[:, :, 2])
        
        # Low saturation = grayscale colors
        if mean_sat < 40:
            if mean_val < 50:
                return "Black"
            elif mean_val > 200:
                return "White"
            else:
                return "Gray"
        
        # Color detection based on hue
        if mean_hue < 10 or mean_hue > 170:
            return "Red"
        elif mean_hue < 25:
            return "Orange"
        elif mean_hue < 35:
            return "Yellow"
        elif mean_hue < 85:
            return "Green"
        elif mean_hue < 130:
            return "Blue"
        elif mean_hue < 170:
            return "Purple"
        
        return "Unknown"
    


# Usage example
if __name__ == "__main__":
    # Test the detector
    detector = BrickDetector()
    
    # Test with existing test image
    if os.path.exists("test_lego.jpg"):
        print("\n🔍 Testing detection...")
        results = detector.detect_bricks("test_lego.jpg")
        
        print(f"\n📊 Detected {len(results)} bricks:")
        for brick in results:
            print(f"   - {brick['name']} ({brick['color']}) @ {brick['confidence']:.2%}")
    else:
        print("⚠️  No test image found. Place 'test_lego.jpg' in backend/ to test.")

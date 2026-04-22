import cv2
import numpy as np
import onnxruntime as ort
import os
import logging

logger = logging.getLogger(__name__)


class YOLODetector:
    """YOLOv8 ONNX detector for LEGO brick detection."""
    
    def __init__(self, model_path="models/best.onnx", classes_path="models/classes.txt",
                 conf_threshold=0.25, iou_threshold=0.45):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"ONNX model not found: {model_path}")
        
        self.session = ort.InferenceSession(model_path)
        self.input_name = self.session.get_inputs()[0].name
        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        
        # Load class names
        if os.path.exists(classes_path):
            self.class_names = open(classes_path).read().strip().split("\n")
        else:
            self.class_names = [f"class_{i}" for i in range(48)]
        
        logger.info(f"YOLOv8 loaded: {len(self.class_names)} classes, conf={conf_threshold}")
    
    def detect(self, image_bytes):
        """Run detection on raw image bytes. Returns dict with detections and counts."""
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return {"detections": [], "total_bricks": 0, "brick_counts": {}}
        
        orig_h, orig_w = img.shape[:2]
        
        # Preprocess: resize to 640x640, normalize, CHW, add batch dim
        img_resized = cv2.resize(img, (640, 640))
        blob = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
        blob = np.transpose(blob, (2, 0, 1))[np.newaxis, ...]
        
        # Run inference
        outputs = self.session.run(None, {self.input_name: blob})
        
        # Parse output: shape [1, 4+num_classes, 8400] for YOLOv8
        predictions = outputs[0][0].T  # [8400, 4+num_classes]
        
        detections = []
        boxes_for_nms = []
        scores_for_nms = []
        
        for pred in predictions:
            scores = pred[4:]
            max_score = float(np.max(scores))
            if max_score < self.conf_threshold:
                continue
            
            class_id = int(np.argmax(scores))
            cx, cy, w, h = pred[:4]
            
            # Scale back to original image coordinates
            scale_x = orig_w / 640
            scale_y = orig_h / 640
            x1 = int((cx - w / 2) * scale_x)
            y1 = int((cy - h / 2) * scale_y)
            x2 = int((cx + w / 2) * scale_x)
            y2 = int((cy + h / 2) * scale_y)
            
            detections.append({
                "class_id": class_id,
                "class_name": self.class_names[class_id] if class_id < len(self.class_names) else f"class_{class_id}",
                "confidence": round(max_score, 4),
                "bbox": {"x1": max(0, x1), "y1": max(0, y1), "x2": min(orig_w, x2), "y2": min(orig_h, y2)}
            })
            boxes_for_nms.append([x1, y1, x2 - x1, y2 - y1])
            scores_for_nms.append(max_score)
        
        # Non-Maximum Suppression
        if detections:
            indices = cv2.dnn.NMSBoxes(boxes_for_nms, scores_for_nms,
                                        self.conf_threshold, self.iou_threshold)
            if len(indices) > 0:
                indices = indices.flatten()
                detections = [detections[i] for i in indices]
            else:
                detections = []
        
        # Build summary counts
        counts = {}
        for d in detections:
            name = d["class_name"]
            counts[name] = counts.get(name, 0) + 1
        
        return {
            "detections": detections,
            "total_bricks": len(detections),
            "brick_counts": counts
        }

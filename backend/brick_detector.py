# brick_detector.py - ONNX-based LEGO Brick Detector (v2.0 - cleaned up)

from typing import List, Dict, Tuple

import cv2
import numpy as np
import onnxruntime
import os
import logging

logger = logging.getLogger(__name__)


class BrickDetector:
    """YOLOv8 ONNX brick detector with colour classification."""

    # Aspect-ratio rules for geometric brick classification.
    # Each entry: (label, min_aspect, max_aspect, max_rel_height)
    #   aspect = bbox_width / bbox_height
    #   rel_height = bbox_height / image_height  (helps separate bricks from plates)
    _BRICK_GEOMETRY = [
        # Plates are thin (small relative height)
        ("1x2 Plate", 1.4, 2.8, 0.06),
        ("2x4 Plate", 2.8, 5.0, 0.06),
        ("2x3 Plate", 1.8, 3.5, 0.06),
        ("2x2 Plate", 0.7, 1.4, 0.06),
        # Bricks (taller relative height)
        ("1x1 Brick", 0.0, 0.8, 1.0),
        ("2x2 Brick", 0.8, 1.3, 1.0),
        ("1x2 Brick", 1.3, 1.8, 1.0),
        ("2x4 Brick", 1.8, 2.8, 1.0),
        ("1x4 Brick", 2.8, 4.0, 1.0),
        ("2x6 Brick", 2.8, 4.5, 1.0),
    ]

    def __init__(
        self,
        model_path: str = "best.onnx",
        conf_threshold: float = 0.20,
        iou_threshold: float = 0.45,
    ):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found: {model_path}")

        logger.info(f"Loading ONNX model from {model_path}")
        self.session = onnxruntime.InferenceSession(
            model_path, providers=["CPUExecutionProvider"]
        )

        self.input_name = self.session.get_inputs()[0].name
        input_shape = self.session.get_inputs()[0].shape
        self.input_size = input_shape[2] if len(input_shape) > 2 else 640

        # Determine how many classes the model actually outputs
        out_shape = self.session.get_outputs()[0].shape
        # YOLOv8 output: [1, 4+num_classes, 8400]
        self.num_model_classes = out_shape[1] - 4 if out_shape[1] < out_shape[2] else 1

        self.conf_threshold = conf_threshold
        self.iou_threshold = iou_threshold
        self.class_names = self._load_class_names()

        logger.info(
            f"Model loaded – input {self.input_size}×{self.input_size}, "
            f"model_classes={self.num_model_classes}, "
            f"label_names={self.class_names}, conf≥{self.conf_threshold}"
        )

    # ------------------------------------------------------------------
    @staticmethod
    def _load_class_names(class_file: str = "class_names.txt") -> List[str]:
        if os.path.exists(class_file):
            with open(class_file) as f:
                return [line.strip() for line in f if line.strip()]
        return ["lego_brick"]

    # ------------------------------------------------------------------
    def detect_bricks(self, image_path: str) -> List[Dict]:
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Cannot read image: {image_path}")

        original_hw = image.shape[:2]
        preprocessed, scale, padding = self._preprocess(image)
        outputs = self.session.run(None, {self.input_name: preprocessed})
        detections = self._postprocess(outputs[0], scale, padding, original_hw)
        return self._format(detections, image)

    # ------------------------------------------------------------------
    def _preprocess(self, img: np.ndarray):
        h, w = img.shape[:2]
        scale = min(self.input_size / h, self.input_size / w)
        new_h, new_w = int(h * scale), int(w * scale)

        resized = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_LINEAR)
        canvas = np.full((self.input_size, self.input_size, 3), 114, dtype=np.uint8)
        pad_h = (self.input_size - new_h) // 2
        pad_w = (self.input_size - new_w) // 2
        canvas[pad_h : pad_h + new_h, pad_w : pad_w + new_w] = resized

        blob = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
        blob = blob.transpose(2, 0, 1)[np.newaxis, ...]
        return blob, scale, (pad_w, pad_h)

    # ------------------------------------------------------------------
    def _postprocess(self, preds: np.ndarray, scale, padding, original_hw):
        preds = np.squeeze(preds).T  # [8400, 4+C]

        boxes = preds[:, :4]
        scores = preds[:, 4:].max(axis=1)
        class_ids = preds[:, 4:].argmax(axis=1)

        mask = scores > self.conf_threshold
        boxes, scores, class_ids = boxes[mask], scores[mask], class_ids[mask]

        if len(boxes) == 0:
            return []

        boxes = self._xywh2xyxy(boxes)
        keep = self._nms(boxes, scores)
        if len(keep) == 0:
            return []

        boxes, scores, class_ids = boxes[keep], scores[keep], class_ids[keep]
        boxes = self._rescale(boxes, scale, padding, original_hw)

        img_h = original_hw[0]
        results = []
        for box, score, cid in zip(boxes, scores, class_ids):
            # If the model is single-class, classify by bounding-box geometry
            if self.num_model_classes == 1:
                class_name = self._classify_by_geometry(box, img_h)
            else:
                class_name = (
                    self.class_names[cid]
                    if cid < len(self.class_names)
                    else "unknown"
                )
            results.append({
                "bbox": box.tolist(),
                "confidence": float(score),
                "class_id": int(cid),
                "class_name": class_name,
            })
        return results

    # ------------------------------------------------------------------
    @classmethod
    def _classify_by_geometry(cls, bbox_xyxy: np.ndarray, img_h: int) -> str:
        """Classify a detected brick by its bounding-box aspect ratio.

        Works with single-class models that only detect 'lego brick'
        without distinguishing types. Uses width/height ratio and
        relative height to differentiate bricks from plates.
        """
        x1, y1, x2, y2 = bbox_xyxy
        w = max(float(x2 - x1), 1.0)
        h = max(float(y2 - y1), 1.0)
        aspect = w / h
        rel_h = h / max(img_h, 1)

        for label, lo, hi, max_rh in cls._BRICK_GEOMETRY:
            if lo <= aspect < hi and rel_h <= max_rh:
                return label

        # Fallback: generic brick
        return "2x4 Brick"

    # ------------------------------------------------------------------
    @staticmethod
    def _xywh2xyxy(boxes: np.ndarray) -> np.ndarray:
        out = boxes.copy()
        out[:, 0] = boxes[:, 0] - boxes[:, 2] / 2
        out[:, 1] = boxes[:, 1] - boxes[:, 3] / 2
        out[:, 2] = boxes[:, 0] + boxes[:, 2] / 2
        out[:, 3] = boxes[:, 1] + boxes[:, 3] / 2
        return out

    def _nms(self, boxes: np.ndarray, scores: np.ndarray) -> np.ndarray:
        indices = cv2.dnn.NMSBoxes(
            boxes.tolist(),
            scores.tolist(),
            score_threshold=self.conf_threshold,
            nms_threshold=self.iou_threshold,
        )
        return indices.flatten() if len(indices) > 0 else np.array([], dtype=int)

    @staticmethod
    def _rescale(boxes, scale, padding, original_hw):
        pad_w, pad_h = padding
        boxes[:, [0, 2]] -= pad_w
        boxes[:, [1, 3]] -= pad_h
        boxes /= scale
        boxes[:, [0, 2]] = boxes[:, [0, 2]].clip(0, original_hw[1])
        boxes[:, [1, 3]] = boxes[:, [1, 3]].clip(0, original_hw[0])
        return boxes

    # ------------------------------------------------------------------
    def _format(self, detections: list, image: np.ndarray) -> List[Dict]:
        results: List[Dict] = []
        counts: Dict[str, int] = {}
        for det in detections:
            name = det["class_name"]
            counts[name] = counts.get(name, 0) + 1
            x1, y1, x2, y2 = (int(v) for v in det["bbox"])
            roi = image[max(y1, 0) : max(y2, 0), max(x1, 0) : max(x2, 0)]
            results.append(
                {
                    "id": f"{name}_{counts[name]}",
                    "name": name,
                    "color": self._detect_colour(roi),
                    "quantity": 1,
                    "confidence": det["confidence"],
                    "bbox": [x1, y1, int(x2 - x1), int(y2 - y1)],
                }
            )
        return results

    # ------------------------------------------------------------------
    @staticmethod
    def _detect_colour(roi: np.ndarray) -> str:
        if roi.size == 0 or roi.shape[0] < 5 or roi.shape[1] < 5:
            return "Unknown"
        hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        h, s, v = (float(np.mean(hsv[:, :, c])) for c in range(3))

        if s < 40:
            return "Black" if v < 50 else ("White" if v > 200 else "Gray")
        if h < 10 or h > 170:
            return "Red"
        if h < 25:
            return "Orange"
        if h < 35:
            return "Yellow"
        if h < 85:
            return "Green"
        if h < 130:
            return "Blue"
        if h < 170:
            return "Purple"
        return "Unknown"


# ---------------------------------------------------------------------------
if __name__ == "__main__":
    det = BrickDetector()
    if os.path.exists("test_lego.jpg"):
        res = det.detect_bricks("test_lego.jpg")
        print(f"Detected {len(res)} brick(s):")
        for r in res:
            print(f"  {r['name']} ({r['color']}) @ {r['confidence']:.0%}")
    else:
        print("Place test_lego.jpg in backend/ to test.")

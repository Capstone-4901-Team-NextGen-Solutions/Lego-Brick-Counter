# brick_detector.py - ONNX-based LEGO Brick Detector (v3.0 - enhanced classification)

from typing import List, Dict, Tuple

import cv2
import numpy as np
import onnxruntime
import os
import logging

logger = logging.getLogger(__name__)


class BrickDetector:
    """YOLOv8 ONNX brick detector with enhanced type and colour classification.

    Uses CLAHE + bilateral-filter + unsharp-mask pre-processing for
    low-quality image resilience, multi-pass detection (enhanced + original),
    and a score-based type classifier that combines orientation-normalized
    aspect ratio, stud counting, plate/brick discrimination, and relative
    area context.
    """

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
            f"Model loaded - input {self.input_size}x{self.input_size}, "
            f"model_classes={self.num_model_classes}, "
            f"label_names={self.class_names}, conf>={self.conf_threshold}"
        )

    # ------------------------------------------------------------------
    @staticmethod
    def _load_class_names(class_file: str = "class_names.txt") -> List[str]:
        if os.path.exists(class_file):
            with open(class_file) as f:
                return [line.strip() for line in f if line.strip()]
        return ["lego_brick"]

    # ------------------------------------------------------------------
    # Image enhancement for low-quality inputs
    # ------------------------------------------------------------------
    @staticmethod
    def _enhance_image(img: np.ndarray) -> np.ndarray:
        """Apply CLAHE contrast boost, bilateral denoise, and unsharp-mask."""
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        l_ch, a_ch, b_ch = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
        l_ch = clahe.apply(l_ch)
        enhanced = cv2.merge([l_ch, a_ch, b_ch])
        enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)
        # Edge-preserving denoise
        enhanced = cv2.bilateralFilter(enhanced, 5, 50, 50)
        # Unsharp mask (sharpen)
        blurred = cv2.GaussianBlur(enhanced, (0, 0), 2.0)
        enhanced = cv2.addWeighted(enhanced, 1.3, blurred, -0.3, 0)
        return enhanced

    @staticmethod
    def _estimate_quality(img: np.ndarray) -> float:
        """Laplacian variance as a proxy for image sharpness / quality."""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        return float(cv2.Laplacian(gray, cv2.CV_64F).var())

    # ------------------------------------------------------------------
    # Main detection entry point
    # ------------------------------------------------------------------
    def detect_bricks(self, image_path: str) -> List[Dict]:
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Cannot read image: {image_path}")

        original_hw = image.shape[:2]
        quality = self._estimate_quality(image)
        logger.info(f"Image quality (Laplacian var): {quality:.1f}")

        # Primary pass on contrast-enhanced / sharpened copy
        enhanced = self._enhance_image(image)
        detections = self._run_inference(enhanced, original_hw)

        # For low-quality or sparse results, also run on the original and merge
        if quality < 200 or len(detections) == 0:
            dets_orig = self._run_inference(image, original_hw)
            detections = self._merge_detections(detections, dets_orig)
            logger.info(
                f"Multi-pass merge: {len(detections)} detections "
                f"(quality={quality:.0f})"
            )

        return self._format(detections, image)

    def _run_inference(self, img: np.ndarray, original_hw) -> list:
        """Single-pass ONNX inference on an already-loaded image."""
        preprocessed, scale, padding = self._preprocess(img)
        outputs = self.session.run(None, {self.input_name: preprocessed})
        return self._postprocess(outputs[0], scale, padding, original_hw)

    def _merge_detections(self, dets1: list, dets2: list) -> list:
        """Merge two detection lists; NMS removes duplicates."""
        combined = dets1 + dets2
        if len(combined) <= 1:
            return combined
        boxes = np.array([d["bbox"] for d in combined])
        scores = np.array([d["confidence"] for d in combined])
        keep = self._nms(boxes, scores)
        return [combined[i] for i in keep]

    # ------------------------------------------------------------------
    def _preprocess(self, img: np.ndarray):
        h, w = img.shape[:2]
        scale = min(self.input_size / h, self.input_size / w)
        new_h, new_w = int(h * scale), int(w * scale)

        # Use CUBIC for upscale, AREA for downscale (sharper than LINEAR)
        interp = cv2.INTER_CUBIC if scale > 1.0 else cv2.INTER_AREA
        resized = cv2.resize(img, (new_w, new_h), interpolation=interp)
        canvas = np.full((self.input_size, self.input_size, 3), 114, dtype=np.uint8)
        pad_h = (self.input_size - new_h) // 2
        pad_w = (self.input_size - new_w) // 2
        canvas[pad_h : pad_h + new_h, pad_w : pad_w + new_w] = resized

        blob = cv2.cvtColor(canvas, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
        blob = blob.transpose(2, 0, 1)[np.newaxis, ...]
        return blob, scale, (pad_w, pad_h)

    # ------------------------------------------------------------------
    def _postprocess(self, preds: np.ndarray, scale, padding, original_hw):
        """Return raw detections (bbox xyxy, confidence, class_id).

        Type classification is deferred to _format() where full image
        context (all detections, ROIs, relative areas) is available.
        """
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

        results = []
        for box, score, cid in zip(boxes, scores, class_ids):
            results.append({
                "bbox": box.tolist(),
                "confidence": float(score),
                "class_id": int(cid),
            })
        return results

    # ------------------------------------------------------------------
    # Stud-count-first brick type classifier
    # ------------------------------------------------------------------
    @classmethod
    def _classify_brick(
        cls,
        bbox_xyxy: np.ndarray,
        img_h: int,
        roi: np.ndarray = None,
    ) -> str:
        """Classify brick type using stud counting as primary signal.

        Strategy (in priority order):
          1. Count studs on the ROI -- if we get a reliable count (>= 4), map it
             directly to a brick type.
          2. Counts of 1-3 are discarded (too often false positives from
             noise circles in HoughCircles / blob detection).
          3. When stud counting is unreliable, use aspect ratio only for
             clearly elongated bricks (1x4, 2x6).
          4. Default: 2x4 Brick -- the most common LEGO piece, and the
             most likely type when a single-class model only provides a
             bounding box with no type info.
        """
        x1, y1, x2, y2 = bbox_xyxy
        w = max(float(x2 - x1), 1.0)
        h = max(float(y2 - y1), 1.0)

        # Orientation-normalized aspect (always >= 1.0)
        aspect = max(w, h) / max(min(w, h), 1.0)

        # Plate detection: thin dimension relative to image height
        rel_thin = min(w, h) / max(img_h, 1)
        is_plate = rel_thin < 0.06

        # ------ 1. Try stud counting (only trust >= 4) ------
        studs = cls._count_studs_robust(roi) if roi is not None else 0

        if studs >= 11:
            label = "2x6 Brick"
        elif studs >= 5:
            label = "2x4 Brick"
        elif studs == 4:
            # 4 studs: 2x2 or 1x4 -- disambiguate by aspect
            label = "1x4 Brick" if aspect > 2.5 else "2x2 Brick"
        else:
            # ------ 2. Stud count unreliable (<4). Use geometry. ------
            # Only trust aspect ratio for clearly elongated shapes.
            if aspect > 3.5:
                label = "2x6 Brick"
            elif aspect > 2.5:
                label = "1x4 Brick"
            else:
                # Squarish or moderately elongated bbox.  With a single-
                # class model this could be anything (1x1, 2x2, 1x2,
                # 2x4).  Default to 2x4 Brick -- it is the most common
                # LEGO brick and the model bounding boxes are nearly
                # square for 2x4 bricks at typical camera angles.
                label = "2x4 Brick"

        if is_plate:
            label = label.replace("Brick", "Plate")

        logger.debug(
            f"Classifier: studs={studs} aspect={aspect:.2f} -> {label}"
        )
        return label

    # ------------------------------------------------------------------
    # Robust stud counting (multiple strategies, best-of)
    # ------------------------------------------------------------------
    @staticmethod
    def _count_studs_robust(roi: np.ndarray) -> int:
        """Count studs on a brick ROI using multiple detection strategies.

        Tries HoughCircles with varied params + SimpleBlobDetector on both
        raw and CLAHE-enhanced grayscale. Returns the best consistent count.
        """
        if roi is None or roi.size == 0 or roi.shape[0] < 20 or roi.shape[1] < 20:
            return 0

        rh, rw = roi.shape[:2]
        gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)

        # CLAHE-enhanced version for better stud visibility
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(4, 4))
        enhanced = clahe.apply(gray)

        counts: List[int] = []
        min_dim = min(rh, rw)

        # --- Strategy 1: HoughCircles with multiple param combos ---
        for src in [gray, enhanced]:
            blurred = cv2.GaussianBlur(src, (5, 5), 1.0)
            for dp in [1.0, 1.2, 1.5]:
                for p2 in [20, 28, 38]:
                    min_r = max(2, int(min_dim * 0.03))
                    max_r = max(min_r + 2, int(min_dim * 0.15))
                    circles = cv2.HoughCircles(
                        blurred,
                        cv2.HOUGH_GRADIENT,
                        dp=dp,
                        minDist=max(min_r * 2, 8),
                        param1=50,
                        param2=p2,
                        minRadius=min_r,
                        maxRadius=max_r,
                    )
                    if circles is not None:
                        counts.append(len(circles[0]))

        # --- Strategy 2: SimpleBlobDetector ---
        for src in [gray, enhanced]:
            params = cv2.SimpleBlobDetector_Params()
            params.filterByColor = False
            params.filterByArea = True
            params.minArea = max(4, (min_dim * 0.03) ** 2 * 3.14)
            params.maxArea = (min_dim * 0.16) ** 2 * 3.14
            params.filterByCircularity = True
            params.minCircularity = 0.5
            params.filterByConvexity = True
            params.minConvexity = 0.6
            params.filterByInertia = True
            params.minInertiaRatio = 0.4
            detector = cv2.SimpleBlobDetector_create(params)
            keypoints = detector.detect(src)
            if keypoints:
                counts.append(len(keypoints))

        if not counts:
            return 0

        # Pick the most common reasonable count (mode).
        # Cap at 12 (2x6 max) and filter out noise (> 14).
        counts = [c for c in counts if 1 <= c <= 14]
        if not counts:
            return 0

        # Return the mode (most frequently detected count)
        from collections import Counter
        counter = Counter(counts)
        mode_count, _ = counter.most_common(1)[0]
        return mode_count

    # ------------------------------------------------------------------
    @staticmethod
    def _xywh2xyxy(boxes: np.ndarray) -> np.ndarray:
        out = boxes.copy()
        out[:, 0] = boxes[:, 0] - boxes[:, 2] / 2
        out[:, 1] = boxes[:, 1] - boxes[:, 3] / 2
        out[:, 2] = boxes[:, 0] + boxes[:, 2] / 2
        out[:, 3] = boxes[:, 1] + boxes[:, 3] / 2
        return out

    def _nms(self, boxes_xyxy: np.ndarray, scores: np.ndarray) -> np.ndarray:
        # cv2.dnn.NMSBoxes expects (x, y, w, h) with top-left origin
        xywh = boxes_xyxy.copy()
        xywh[:, 2] = boxes_xyxy[:, 2] - boxes_xyxy[:, 0]  # width
        xywh[:, 3] = boxes_xyxy[:, 3] - boxes_xyxy[:, 1]  # height
        indices = cv2.dnn.NMSBoxes(
            xywh.tolist(),
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
        if not detections:
            return []

        img_h, img_w = image.shape[:2]

        # Pre-compute ROIs for classification
        rois: List[np.ndarray] = []
        for det in detections:
            x1, y1, x2, y2 = (int(v) for v in det["bbox"])
            roi = image[max(y1, 0) : max(y2, 0), max(x1, 0) : max(x2, 0)]
            rois.append(roi)

        results: List[Dict] = []
        counts: Dict[str, int] = {}
        for i, det in enumerate(detections):
            x1, y1, x2, y2 = (int(v) for v in det["bbox"])
            bbox_arr = np.array(det["bbox"])

            # Type classification with full context
            if self.num_model_classes == 1:
                name = self._classify_brick(
                    bbox_arr,
                    img_h,
                    roi=rois[i],
                )
            else:
                cid = det["class_id"]
                name = (
                    self.class_names[cid]
                    if cid < len(self.class_names)
                    else "unknown"
                )

            counts[name] = counts.get(name, 0) + 1
            results.append(
                {
                    "id": f"{name}_{counts[name]}",
                    "name": name,
                    "color": self._detect_colour(rois[i]),
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

        # Center-crop to the inner 60% to avoid background bleed
        rh, rw = roi.shape[:2]
        margin_y, margin_x = int(rh * 0.2), int(rw * 0.2)
        cropped = roi[margin_y:rh - margin_y, margin_x:rw - margin_x]
        if cropped.size == 0 or cropped.shape[0] < 3 or cropped.shape[1] < 3:
            cropped = roi

        hsv = cv2.cvtColor(cropped, cv2.COLOR_BGR2HSV)
        # Use median for robustness against outlier pixels
        h = float(np.median(hsv[:, :, 0]))
        s = float(np.median(hsv[:, :, 1]))
        v = float(np.median(hsv[:, :, 2]))

        # Low saturation -> achromatic
        if s < 45:
            if v < 55:
                return "Black"
            if v > 190:
                return "White"
            return "Gray"

        # Hue-based classification (OpenCV hue range: 0-179)
        if h < 9 or h > 165:
            return "Red"
        if h < 18:
            # Distinguish dark orange from red by brightness
            return "Red" if v < 130 else "Orange"
        if h < 35:
            return "Yellow"
        if h < 82:
            return "Green"
        if h < 130:
            return "Blue"
        if h < 165:
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

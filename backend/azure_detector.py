# azure_detector.py

import os
import cv2
import numpy as np
import logging
from typing import List, Dict
from azure.cognitiveservices.vision.customvision.prediction import CustomVisionPredictionClient
from msrest.authentication import ApiKeyCredentials

logger = logging.getLogger(__name__)


class AzureDetector:

    LEGO_ID_MAP = {
        'Brick 1 x 1':        '3005',
        'Brick 1 x 1 x 5':    '2453',
        'Brick 1 x 10':       '6111',
        'Brick 1 x 2':        '3004',
        'Brick 1 x 2 x 2':    '3245',
        'Brick 1 x 2 x 5':    '2454',
        'Brick 1 x 3':        '3622',
        'Brick 1 x 4':        '3010',
        'Brick 1 x 6':        '3009',
        'Brick 1 x 8':        '3008',
        'Brick 2 x 2':        '3003',
        'Brick 2 x 2 Corner': '2357',
        'Brick 2 x 2 Slope':  '3039',
        'Brick 2 x 3':        '3002',
        'Brick 2 x 4':        '3001',
        'Brick 2 x 6':        '2456',
        'Brick 2 x 8':        '3007',
        'Plate 1 x 1':        '3024',
        'Plate 1 x 1 Round':  '4073',
        'Plate 1 x 10':       '4477',
        'Plate 1 x 12':       '60479',
        'Plate 1 x 2':        '3023',
        'Plate 1 x 3':        '3623',
        'Plate 1 x 4':        '3710',
        'Plate 1 x 6':        '3666',
        'Plate 1 x 8':        '3460',
        'Plate 2 x 10':       '3832',
        'Plate 2 x 12':       '2445',
        'Plate 2 x 16':       '4282',
        'Plate 2 x 2':        '3022',
        'Plate 2 x 2 Corner': '2420',
        'Plate 2 x 3':        '3021',
        'Plate 2 x 4':        '3020',
        'Plate 2 x 6':        '3795',
        'Plate 2 x 8':        '3034',
        'Plate 3 x 3':        '11212',
        'Plate 4 x 4':        '3031',
        'Plate 4 x 4 Corner': '2639',
        'Plate 4 x 6':        '3032',
        'Plate 4 x 8':        '3035',
        'Plate 6 x 10':       '3033',
        'Plate 6 x 6':        '3958',
        'Tile 1 x 3':         '63864',
        'Tile 1 x 4':         '2431',
        'Tile 1 x 6':         '6636',
        'Tile 1 x 8':         '4162',
        'Tile 2 x 2':         '3068',
        'Tile 2 x 4':         '87079',
        '2x4 Brick':          '3001',
        '2x2 Brick':          '3003',
        '1x2 Plate':          '3023',
        'lego_brick':         '3001',
    }

    # HSV color ranges tuned for LEGO plastics under typical indoor lighting.
    # Each entry is a list of (h_min, h_max, s_min, s_max, v_min, v_max).
    # OpenCV hue is 0-179.
    LEGO_COLORS = {
        'Red':        [(0,   8,  100, 255,  80, 255),
                       (165, 179, 100, 255,  80, 255)],
        'Orange':     [(9,   20, 120, 255, 100, 255)],
        'Yellow':     [(21,  35, 100, 255, 100, 255)],
        'Lime':       [(36,  50,  80, 255,  80, 255)],
        'Green':      [(51,  85,  60, 255,  40, 220)],
        'Cyan':       [(86, 100,  80, 255,  80, 255)],
        'Blue':       [(101, 130,  80, 255,  40, 255)],
        'Purple':     [(131, 150,  60, 255,  40, 220)],
        'Magenta':    [(151, 164,  80, 255,  80, 255)],
        'White':      [(0,  179,   0,  60, 180, 255)],
        'Light Gray': [(0,  179,   0,  60, 120, 179)],
        'Dark Gray':  [(0,  179,   0,  60,  50, 119)],
        'Black':      [(0,  179,   0, 255,   0,  49)],
        'Brown':      [(10,  25,  60, 200,  30, 140)],
        'Tan':        [(15,  30,  30, 120, 140, 220)],
    }

    def __init__(
        self,
        prediction_key: str = None,
        prediction_endpoint: str = None,
        project_id: str = None,
        published_name: str = None,
        conf_threshold: float = 0.10,   #Lowered confidence threshold from 0.25 to 0.10
        nms_iou_threshold: float = 0.45,
    ):
        self.prediction_key       = prediction_key       or os.getenv('AZURE_CV_PREDICTION_KEY')
        self.prediction_endpoint  = prediction_endpoint  or os.getenv('AZURE_CV_PREDICTION_ENDPOINT')
        self.project_id           = project_id           or os.getenv('AZURE_CV_PROJECT_ID')
        self.published_name       = published_name       or os.getenv('AZURE_CV_PUBLISHED_NAME', 'Iteration2')
        self.conf_threshold       = conf_threshold
        self.nms_iou_threshold    = nms_iou_threshold

        if not all([self.prediction_key, self.prediction_endpoint, self.project_id]):
            raise ValueError(
                "Missing Azure credentials. Set:\n"
                "  AZURE_CV_PREDICTION_KEY\n"
                "  AZURE_CV_PREDICTION_ENDPOINT\n"
                "  AZURE_CV_PROJECT_ID"
            )

        logger.info("Initializing Azure Custom Vision...")
        logger.info(f"   Endpoint:  {self.prediction_endpoint}")
        logger.info(f"   Project:   {self.project_id}")
        logger.info(f"   Published: {self.published_name}")
        logger.info(f"   Threshold: {self.conf_threshold}")

        credentials = ApiKeyCredentials(in_headers={"Prediction-key": self.prediction_key})
        self.predictor = CustomVisionPredictionClient(self.prediction_endpoint, credentials)
        logger.info("Azure detector initialized")

    # ── Public API ────────────────────────────────────────────────────────────

    def detect_bricks(self, image_path: str) -> List[Dict]:
        logger.info(f"🔍 Running Azure detection on: {image_path}")

        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Cannot read image: {image_path}")
        img_h, img_w = image.shape[:2]

        with open(image_path, "rb") as f:
            image_data = f.read()

        results = self.predictor.detect_image(
            self.project_id, self.published_name, image_data
        )
        logger.info(f"📊 Azure returned {len(results.predictions)} predictions")

        #1. Confidence filter
        candidates = [p for p in results.predictions if p.probability >= self.conf_threshold]
        logger.info(f"   After confidence filter ({self.conf_threshold}): {len(candidates)}")

        #2. Convert normalised bboxes to pixels
        raw = []
        for pred in candidates:
            b = pred.bounding_box
            x = max(0, int(b.left  * img_w))
            y = max(0, int(b.top   * img_h))
            w = max(1, min(int(b.width  * img_w), img_w - x))
            h = max(1, min(int(b.height * img_h), img_h - y))
            raw.append({
                'name':       pred.tag_name,
                'confidence': pred.probability,
                'bbox':       [x, y, w, h],
            })

        #3. Per-class NMS — removes redundant overlapping boxes
        deduped = self._nms_per_class(raw)
        logger.info(f"   After NMS: {len(deduped)}")

        #4. Color detection for each surviving detection
        detections = []
        for det in deduped:
            x, y, w, h = det['bbox']
            roi = image[y:y + h, x:x + w]
            color = self._detect_color_robust(roi, image, x, y, w, h)
            detections.append({
                'id':         self._map_to_lego_id(det['name']),
                'name':       det['name'],
                'color':      color,
                'quantity':   1,
                'confidence': det['confidence'],
                'bbox':       det['bbox'],
            })

        logger.info(f"Final detections: {len(detections)}")
        return detections

    # ── NMS ───────────────────────────────────────────────────────────────────

    def _nms_per_class(self, detections: list) -> list:
        """Non-maximum suppression applied per brick class."""
        if not detections:
            return []

        by_class: Dict[str, list] = {}
        for d in detections:
            by_class.setdefault(d['name'], []).append(d)

        kept = []
        for class_dets in by_class.values():
            class_dets.sort(key=lambda d: d['confidence'], reverse=True)
            surviving = []
            for candidate in class_dets:
                if not any(
                    self._iou(candidate['bbox'], s['bbox']) > self.nms_iou_threshold
                    for s in surviving
                ):
                    surviving.append(candidate)
            kept.extend(surviving)

        return kept

    @staticmethod
    def _iou(box1: list, box2: list) -> float:
        x1, y1, w1, h1 = box1
        x2, y2, w2, h2 = box2
        xa = max(x1, x2);          ya = max(y1, y2)
        xb = min(x1 + w1, x2 + w2); yb = min(y1 + h1, y2 + h2)
        inter = max(0, xb - xa) * max(0, yb - ya)
        union = w1 * h1 + w2 * h2 - inter
        return inter / union if union > 0 else 0.0

    # ── Color detection ───────────────────────────────────────────────────────

    def _detect_color_robust(
        self,
        roi: np.ndarray,
        full_image: np.ndarray,
        x: int, y: int, w: int, h: int,
    ) -> str:
        """
        Three-stage color detection, most-reliable-first:
          1. Centre 50% crop of the ROI (avoids shadow/edge artefacts)
          2. Full ROI
          3. Inset ROI (10% padding to trim object edges)
        """
        #Stage 1 — centre crop
        if roi.shape[0] >= 10 and roi.shape[1] >= 10:
            ry0 = roi.shape[0] // 4;  ry1 = roi.shape[0] * 3 // 4
            rx0 = roi.shape[1] // 4;  rx1 = roi.shape[1] * 3 // 4
            color = self._classify_color(roi[ry0:ry1, rx0:rx1])
            if color != 'Unknown':
                return color

        #Stage 2 — full ROI
        if roi.shape[0] >= 5 and roi.shape[1] >= 5:
            color = self._classify_color(roi)
            if color != 'Unknown':
                return color

        #Stage 3 — inset by 10%
        img_h, img_w = full_image.shape[:2]
        px = max(int(w * 0.10), 2);  py = max(int(h * 0.10), 2)
        ix = min(x + px, img_w - 1); iy = min(y + py, img_h - 1)
        iw = max(1, w - 2 * px);     ih = max(1, h - 2 * py)
        inset = full_image[iy:iy + ih, ix:ix + iw]
        color = self._classify_color(inset)
        return color if color != 'Unknown' else 'Unknown'

    def _classify_color(self, roi: np.ndarray) -> str:
        """
        Pixel-voting color classification against LEGO HSV ranges.
        Returns the color whose mask covers the most pixels,
        provided it covers at least 15% of the ROI.
        """
        if roi is None or roi.size == 0 or roi.shape[0] < 3 or roi.shape[1] < 3:
            return 'Unknown'

        try:
            hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        except Exception:
            return 'Unknown'

        total = hsv.shape[0] * hsv.shape[1]
        votes: Dict[str, int] = {}

        for color_name, ranges in self.LEGO_COLORS.items():
            mask = np.zeros((hsv.shape[0], hsv.shape[1]), dtype=np.uint8)
            for r in ranges:
                h_min, h_max, s_min, s_max, v_min, v_max = r
                mask |= cv2.inRange(
                    hsv,
                    np.array([h_min, s_min, v_min]),
                    np.array([h_max, s_max, v_max]),
                )
            votes[color_name] = int(np.sum(mask > 0))

        best  = max(votes, key=votes.get)
        ratio = votes[best] / total if total > 0 else 0

        #Require at least 15% pixel coverage to avoid noise misclassification
        return best if ratio >= 0.15 else 'Unknown'

    # ── ID mapping ────────────────────────────────────────────────────────────

    def _map_to_lego_id(self, brick_name: str) -> str:
        if brick_name in self.LEGO_ID_MAP:
            return self.LEGO_ID_MAP[brick_name]
        lower = brick_name.lower()
        for key, val in self.LEGO_ID_MAP.items():
            if key.lower() == lower:
                return val
        for key, val in self.LEGO_ID_MAP.items():
            if key.lower() in lower or lower in key.lower():
                return val
        return '0000'
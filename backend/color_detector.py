import cv2
import numpy as np


class LegoColorClassifier:
    def __init__(self):
        self.lego_colors_rgb = {
            'Red':         (196, 40,  27),
            'Dark Red':    (114, 14,  15),
            'Orange':      (218, 133, 65),
            'Yellow':      (240, 205, 97),
            'Lime Green':  (0,   175, 77),
            'Green':       (0,   143, 65),
            'Dark Green':  (0,   69,  26),
            'Light Blue':  (104, 195, 226),
            'Medium Blue': (115, 150, 200),
            'Blue':        (13,  105, 171),
            'Dark Blue':   (0,   32,  96),
            'Sand Blue':   (90,  113, 132),
            'Purple':      (107, 50,  124),
            'Magenta':     (163, 0,   91),
            'White':       (242, 243, 242),
            'Light Gray':  (163, 162, 164),
            'Dark Gray':   (99,  95,  97),
            'Black':       (27,  42,  52),
            'Brown':       (88,  57,  39),
            'Dark Tan':    (143, 121, 86),
            'Tan':         (222, 198, 156),
        }
        self.lego_lab_palette = {}
        for name, rgb in self.lego_colors_rgb.items():
            self.lego_lab_palette[name] = self.rgb_to_lab(rgb)
        self.debug = False

    @staticmethod
    def rgb_to_lab(rgb):
        r, g, b = rgb
        patch = np.uint8([[[b, g, r]]])
        lab = cv2.cvtColor(patch, cv2.COLOR_BGR2LAB)[0, 0].astype(np.float32)
        return lab

    def _safe_crop(self, img, margin_ratio=0.12):
        h, w = img.shape[:2]
        if h < 12 or w < 12:
            return img
        my = int(h * margin_ratio)
        mx = int(w * margin_ratio)
        return img[my:h-my, mx:w-mx]

    def _center_mask(self, shape, radius_ratio=0.42):
        h, w = shape[:2]
        mask = np.zeros((h, w), dtype=np.uint8)
        cx, cy = w // 2, h // 2
        rx, ry = int(w * radius_ratio), int(h * radius_ratio)
        cv2.ellipse(mask, (cx, cy), (rx, ry), 0, 0, 360, 255, -1)
        return mask > 0

    def _build_brick_mask(self, img_bgr):
        hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
        lab = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2LAB)
        H, S, V = cv2.split(hsv)
        L, A, B = cv2.split(lab)
        center = self._center_mask(img_bgr.shape)
        not_glare = ~((V > 245) & (S < 30))
        not_deep_shadow = V > 20
        chromatic = S > 35
        neutral = (S <= 35) & (L > 35) & (L < 240)
        mask = center & not_glare & not_deep_shadow & (chromatic | neutral)
        return mask

    def _robust_representative_lab(self, img_bgr, mask):
        lab = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2LAB).astype(np.float32)
        pixels = lab[mask]
        if len(pixels) < 40:
            return None
        low = np.percentile(pixels, 10, axis=0)
        high = np.percentile(pixels, 90, axis=0)
        keep = np.all((pixels >= low) & (pixels <= high), axis=1)
        trimmed = pixels[keep]
        if len(trimmed) < 20:
            trimmed = pixels
        return np.median(trimmed, axis=0)

    def _lab_distance(self, a, b):
        dL = a[0] - b[0]
        da = a[1] - b[1]
        db = a[2] - b[2]
        return np.sqrt((0.8 * dL) ** 2 + (1.2 * da) ** 2 + (1.2 * db) ** 2)

    def _neutral_override(self, rep_lab):
        L, A, B = rep_lab
        chroma = np.sqrt((A - 128) ** 2 + (B - 128) ** 2)
        if L < 55 and chroma < 18:
            return 'Black'
        if L > 220 and chroma < 15:
            return 'White'
        if 150 < L <= 220 and chroma < 16:
            return 'Light Gray'
        if 70 < L <= 150 and chroma < 16:
            return 'Dark Gray'
        return None

    def classify_crop(self, crop_bgr):
        if crop_bgr is None or crop_bgr.size == 0:
            return 'Unknown'
        crop_bgr = self._safe_crop(crop_bgr, margin_ratio=0.12)
        crop_bgr = cv2.resize(crop_bgr, (96, 96), interpolation=cv2.INTER_AREA)
        mask = self._build_brick_mask(crop_bgr)
        rep_lab = self._robust_representative_lab(crop_bgr, mask)
        if rep_lab is None:
            return 'Unknown'
        neutral_guess = self._neutral_override(rep_lab)
        if neutral_guess is not None:
            return neutral_guess
        best_name = 'Unknown'
        best_dist = float('inf')
        for name, ref_lab in self.lego_lab_palette.items():
            dist = self._lab_distance(rep_lab, ref_lab)
            if dist < best_dist:
                best_dist = dist
                best_name = name
        if self.debug:
            print(f'[ColorDebug] Rep Lab: {rep_lab}, best={best_name}, dist={best_dist:.2f}')
        return best_name

    # ── public interface (keeps app.py call sites unchanged) ──────────────

    def get_dominant_color(self, crop_bgr):
        """Public method — accepts a BGR numpy array crop, returns color name string."""
        return self.classify_crop(crop_bgr)

    def detect_color_from_image(self, image_path):
        """Public method — detects color from full image using center 60% crop."""
        img = cv2.imread(image_path)
        if img is None:
            return 'Unknown'
        h, w = img.shape[:2]
        cy, cx = h // 2, w // 2
        crop = img[int(cy * 0.2):int(cy * 1.8), int(cx * 0.2):int(cx * 1.8)]
        return self.classify_crop(crop)

    def detect_color_from_bbox(self, image_path, bbox):
        """Public method — detects color from normalized bounding box region."""
        img = cv2.imread(image_path)
        if img is None:
            return 'Unknown'
        ih, iw = img.shape[:2]
        x1 = int(bbox.get('left', 0) * iw)
        y1 = int(bbox.get('top', 0) * ih)
        x2 = int((bbox.get('left', 0) + bbox.get('width', 1)) * iw)
        y2 = int((bbox.get('top', 0) + bbox.get('height', 1)) * ih)
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(iw, x2), min(ih, y2)
        if (x2 - x1) < 10 or (y2 - y1) < 10:
            if self.debug:
                print(f'[ColorDebug] Bbox too small ({x2-x1}x{y2-y1}), falling back to full image')
            return self.detect_color_from_image(image_path)
        if self.debug:
            print(f'[ColorDebug] Using bbox crop: ({x1},{y1}) to ({x2},{y2}) on {ih}x{iw} image')
        crop = img[y1:y2, x1:x2]
        return self.classify_crop(crop)


# Backwards-compatible alias so any code referencing HSVColorClassifier still works
HSVColorClassifier = LegoColorClassifier

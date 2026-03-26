import cv2
import numpy as np

# Try to import sklearn for K-Means clustering
try:
    from sklearn.cluster import KMeans
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False


class HSVColorClassifier:
    def __init__(self):
        # LEGO color reference palette in RGB (standard LEGO colors)
        lego_rgb = {
            'Red': (196, 40, 27),
            'Orange': (218, 133, 65),
            'Yellow': (240, 205, 97),
            'Lime Green': (166, 202, 85),
            'Green': (0, 143, 65),
            'Dark Green': (0, 69, 26),
            'Blue': (13, 105, 171),
            'Dark Blue': (0, 32, 96),
            'Light Blue': (104, 195, 226),
            'Purple': (107, 50, 124),
            'White': (242, 243, 242),
            'Light Gray': (163, 162, 164),
            'Dark Gray': (99, 95, 97),
            'Black': (27, 42, 52),
            'Brown': (88, 57, 39),
            'Tan': (222, 198, 156),
        }
        
        # Convert RGB reference palette to Lab color space
        self.lego_colors_lab = {}
        for name, rgb in lego_rgb.items():
            # Create a 1x1 BGR image (OpenCV uses BGR)
            bgr = np.array([[[rgb[2], rgb[1], rgb[0]]]], dtype=np.uint8)
            # Convert to Lab
            lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2Lab)
            # Store as float array [L, a, b]
            self.lego_colors_lab[name] = lab[0, 0].astype(np.float32)

    def get_dominant_color(self, crop_bgr):
        """Extract dominant color from a BGR crop using K-Means in Lab space with CLAHE preprocessing"""
        if crop_bgr is None or crop_bgr.size == 0:
            return 'Unknown'
        
        # Resize for speed
        resized = cv2.resize(crop_bgr, (80, 80))
        
        # Convert to Lab color space
        lab = cv2.cvtColor(resized, cv2.COLOR_BGR2Lab)
        
        # Apply CLAHE to L channel only to normalize lighting
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(4, 4))
        lab[:, :, 0] = clahe.apply(lab[:, :, 0])
        
        # Reshape to pixel array (N, 3) where N = 80*80
        pixels = lab.reshape(-1, 3).astype(np.float32)
        
        # Filter out near-white background pixels (L > 90, a and b near 0)
        # and near-black shadow pixels (L < 15)
        L = pixels[:, 0]
        a = pixels[:, 1]
        b = pixels[:, 2]
        
        # Keep pixels that are NOT near-white and NOT near-black
        mask = ~((L > 90) & (np.abs(a - 128) < 5) & (np.abs(b - 128) < 5)) & (L >= 15)
        filtered_pixels = pixels[mask]
        
        # If too few pixels remain, use all pixels
        if len(filtered_pixels) < 50:
            filtered_pixels = pixels
        
        # Find representative color
        if SKLEARN_AVAILABLE and len(filtered_pixels) >= 3:
            # Use K-Means clustering to find dominant color
            try:
                kmeans = KMeans(n_clusters=min(3, len(filtered_pixels)), n_init=5, random_state=0)
                kmeans.fit(filtered_pixels)
                
                # Find the largest cluster
                labels = kmeans.labels_
                unique, counts = np.unique(labels, return_counts=True)
                largest_cluster_idx = unique[np.argmax(counts)]
                
                # Get centroid of largest cluster
                representative_color = kmeans.cluster_centers_[largest_cluster_idx]
            except Exception:
                # Fallback to median if K-Means fails
                representative_color = np.median(filtered_pixels, axis=0)
        else:
            # Fallback: use median of all non-background pixels
            representative_color = np.median(filtered_pixels, axis=0)
        
        # Find closest LEGO color using Euclidean distance in Lab space
        min_distance = float('inf')
        closest_color = 'Unknown'
        
        for name, lab_ref in self.lego_colors_lab.items():
            distance = np.linalg.norm(representative_color - lab_ref)
            if distance < min_distance:
                min_distance = distance
                closest_color = name
        
        return closest_color

    def detect_color_from_image(self, image_path):
        """Detect dominant color from full image (used when no bounding box available)"""
        img = cv2.imread(image_path)
        if img is None:
            return 'Unknown'
        
        h, w = img.shape[:2]
        # Use center 60% of image to avoid background
        cy, cx = h // 2, w // 2
        crop = img[int(cy * 0.2):int(cy * 1.8), int(cx * 0.2):int(cx * 1.8)]
        
        return self.get_dominant_color(crop)

    def detect_color_from_bbox(self, image_path, bbox):
        """Detect color from bounding box region: bbox = (left, top, width, height) normalized 0-1"""
        img = cv2.imread(image_path)
        if img is None:
            return 'Unknown'
        
        ih, iw = img.shape[:2]
        x1 = int(bbox.get('left', 0) * iw)
        y1 = int(bbox.get('top', 0) * ih)
        x2 = int((bbox.get('left', 0) + bbox.get('width', 1)) * iw)
        y2 = int((bbox.get('top', 0) + bbox.get('height', 1)) * ih)
        
        # Clamp to image boundaries
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(iw, x2), min(ih, y2)
        
        crop = img[y1:y2, x1:x2]
        return self.get_dominant_color(crop)

#!/usr/bin/env python3
"""
Quick test script for ONNX brick detector
Tests detection and visualizes results
"""

from brick_detector import BrickDetector
import cv2
import os
import sys

def main():
    print("=" * 50)
    print("🧱 LEGO BRICK DETECTOR TEST")
    print("=" * 50)
    
    # Initialize detector
    try:
        print("\n🔄 Initializing detector...")
        detector = BrickDetector('best.onnx')
        print("✅ Detector initialized\n")
    except FileNotFoundError as e:
        print(f"❌ Failed to initialize: {e}")
        print("\n💡 Make sure to:")
        print("   1. Place your best.onnx model in backend/")
        print("   2. Run: pip install -r requirements.txt")
        return
    except Exception as e:
        print(f"❌ Failed to initialize: {e}")
        import traceback
        traceback.print_exc()
        return
    
    # Find test image
    test_images = ['test_lego.jpg', 'quick_test.jpg']
    test_image = None
    
    for img in test_images:
        if os.path.exists(img):
            test_image = img
            break
    
    if not test_image:
        print("❌ No test image found!")
        print("   Place 'test_lego.jpg' in backend/ directory")
        print("\n💡 Or specify an image:")
        print(f"   python {sys.argv[0]} path/to/your/image.jpg")
        return
    
    # Allow command-line image path
    if len(sys.argv) > 1:
        test_image = sys.argv[1]
        if not os.path.exists(test_image):
            print(f"❌ Image not found: {test_image}")
            return
    
    print(f"🔍 Testing with: {test_image}\n")
    
    # Run detection
    try:
        results = detector.detect_bricks(test_image)
        
        print(f"📊 RESULTS:")
        print(f"   Detected: {len(results)} bricks\n")
        
        if len(results) == 0:
            print("   ⚠️  No bricks detected!")
            print("\n💡 Troubleshooting:")
            print("   - Try lowering confidence threshold:")
            print("     detector = BrickDetector(conf_threshold=0.15)")
            print("   - Check if image contains LEGO bricks")
            print("   - Verify model was trained correctly")
        else:
            for i, brick in enumerate(results, 1):
                print(f"   Brick {i}:")
                print(f"      Type: {brick['name']}")
                print(f"      Color: {brick['color']}")
                print(f"      Confidence: {brick['confidence']:.2%}")
                print(f"      Position: x={brick['bbox'][0]}, y={brick['bbox'][1]}")
                print()
        
        # Visualize
        print("🎨 Creating visualization...")
        visualize_detections(test_image, results)
        
    except Exception as e:
        print(f"❌ Detection failed: {e}")
        import traceback
        traceback.print_exc()

def visualize_detections(image_path, detections):
    """Draw bounding boxes and save result"""
    img = cv2.imread(image_path)
    
    if img is None:
        print(f"❌ Could not read image: {image_path}")
        return
    
    for det in detections:
        x, y, w, h = det['bbox']
        conf = det['confidence']
        name = det['name']
        color = det['color']
        
        # Draw rectangle
        cv2.rectangle(img, (x, y), (x + w, y + h), (0, 255, 0), 2)
        
        # Draw label background
        label = f"{name} {color} {conf:.2f}"
        (label_w, label_h), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.5, 1)
        cv2.rectangle(img, (x, y - label_h - 10), (x + label_w, y), (0, 255, 0), -1)
        
        # Draw label text
        cv2.putText(img, label, (x, y - 5), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)
    
    # Save result
    output_path = 'detection_result.jpg'
    cv2.imwrite(output_path, img)
    print(f"💾 Visualization saved: {output_path}\n")
    print("✅ Test complete!")

if __name__ == "__main__":
    main()

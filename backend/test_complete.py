# test_complete.py
import requests
import json

# Test Flask server
print("Testing Lego Brick Counter API...")

# 1. Test health endpoint
health_response = requests.get("http://localhost:5000/api/health")
print(f"Health check: {health_response.status_code} - {health_response.json()}")

# 2. Test upload with a test image
test_image_path = "test_lego.jpg"  # Make sure this exists

with open(test_image_path, 'rb') as f:
    files = {'file': ('test_lego.jpg', f, 'image/jpeg')}
    response = requests.post("http://localhost:5000/api/upload", files=files)

if response.status_code == 200:
    results = response.json()
    print(f"\n✅ Upload successful!")
    print(f"Bricks detected: {results['bricks_detected']}")
    print("\nDetected bricks:")
    for brick in results['results']:
        print(f"  - {brick['name']} (ID: {brick['id']}) x{brick['quantity']} - {brick['color']}")
else:
    print(f"\n❌ Upload failed: {response.status_code}")
    print(f"Error: {response.text}")
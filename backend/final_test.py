#final_test.py
import requests
import os
from PIL import Image
import json

def main():
    print("=== FINAL LEGO API TEST ===")
    
    #Test Flask server
    try:
        response = requests.get("http://localhost:5000/api/health")
        print(f"Flask server: {response.status_code}")
        print(f"   Response: {response.json()}")
    except Exception as e:
        print(f"Flask server not reachable: {e}")
        print("   Make sure 'python app.py' is running in another terminal")
        return
    
    #Create test image
    print("\nCreating test image...")
    img = Image.new('RGB', (400, 300), color=(222, 49, 49))
    img.save('test_lego.jpg')
    print("test_lego.jpg created")
    
    #Test upload endpoint
    print("\nTesting upload endpoint...")
    try:
        with open("test_lego.jpg", "rb") as file:
            files = {"file": ("test_lego.jpg", file, "image/jpeg")}
            response = requests.post("http://localhost:5000/api/upload", files=files)
        
        if response.status_code == 200:
            result = response.json()
            print("UPLOAD SUCCESS")
            print(f"   Filename: {result.get('filename')}")
            print(f"   Bricks detected: {result.get('bricks_detected')}")
            print("\n   Detected bricks:")
            for brick in result.get('results', []):
                print(f"     - {brick['name']} (ID: {brick['id']}) x{brick['quantity']}")
        else:
            print(f"Upload failed: {response.status_code}")
            print(f"   Error: {response.text}")
            
    except Exception as e:
        print(f"Upload test failed: {e}")
    
    print("\nTEST COMPLETED")

if __name__ == "__main__":
    main()
    input("\nPress Enter to exit...")
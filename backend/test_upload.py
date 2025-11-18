#test_upload.py
import requests
import json
import os

def test_upload():
    print("Testing Lego API upload endpoint...")
    
    #Check if test image exists
    if not os.path.exists("test_lego.jpg"):
        print("❌ test_lego.jpg not found. Please run create_test_image.py first.")
        return
    
    url = "http://localhost:5000/api/upload"
    
    try:
        #Test file upload
        with open("test_lego.jpg", "rb") as file:
            files = {"file": ("test_lego.jpg", file, "image/jpeg")}
            response = requests.post(url, files=files)
        
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ SUCCESS! Upload worked!")
            print(f"Filename: {result.get('filename')}")
            print(f"Bricks detected: {result.get('bricks_detected', 0)}")
            print("\nDetected bricks:")
            for brick in result.get('results', []):
                print(f"  - {brick['name']} (ID: {brick['id']}) x{brick['quantity']} - {brick['color']}")
        else:
            print("❌ Upload failed")
            print(f"Error: {response.text}")
            
    except Exception as e:
        print(f"❌ Error during upload: {e}")

if __name__ == "__main__":
    test_upload()
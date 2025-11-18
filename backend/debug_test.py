#debug_test.py
import sys
import os

print("=== DEBUG TEST STARTED ===")
print(f"Python version: {sys.version}")
print(f"Current directory: {os.getcwd()}")
print(f"Files in directory: {os.listdir('.')}")

#Test imports
try:
    import requests
    print("✅ requests imported successfully")
except ImportError as e:
    print(f"❌ requests import failed: {e}")

try:
    from PIL import Image
    print("✅ PIL imported successfully")
except ImportError as e:
    print(f"❌ PIL import failed: {e}")

#Test Flask server connectivity
try:
    import requests
    response = requests.get("http://localhost:5000/api/health", timeout=5)
    print(f"✅ Flask server is running: {response.status_code}")
    print(f"Response: {response.json()}")
except Exception as e:
    print(f"❌ Flask server connection failed: {e}")

print("=== DEBUG TEST COMPLETED ===")
input("Press Enter to exit...")
#!/usr/bin/env python3
"""
Test Azure Custom Vision Integration
Tests detector and API endpoints
"""

import os
import sys
import requests
from dotenv import load_dotenv

load_dotenv()

def test_env_variables():
    """Check environment variables"""
    print("=" * 70)
    print("1. TESTING ENVIRONMENT VARIABLES")
    print("=" * 70)
    
    required = [
        'AZURE_CV_PREDICTION_KEY',
        'AZURE_CV_PREDICTION_ENDPOINT',
        'AZURE_CV_PROJECT_ID',
        'AZURE_CV_PUBLISHED_NAME'
    ]
    
    all_present = True
    for var in required:
        value = os.getenv(var)
        if value:
            if 'KEY' in var:
                print(f"✓ {var}: {value[:20]}...")
            else:
                print(f"✓ {var}: {value}")
        else:
            print(f"✗ {var}: NOT SET")
            all_present = False
    
    if not all_present:
        print("\n❌ Missing environment variables!")
        print("Set them in .env file")
        return False
    
    print("\n✅ All environment variables present\n")
    return True

def test_azure_detector():
    """Test Azure detector directly"""
    print("=" * 70)
    print("2. TESTING AZURE DETECTOR")
    print("=" * 70)
    
    try:
        from azure_detector import AzureDetector
        print("✓ Azure detector module imported")
        
        detector = AzureDetector()
        print("✓ Azure detector initialized")
        print(f"  Endpoint: {detector.prediction_endpoint}")
        print(f"  Project: {detector.project_id}")
        print(f"  Published: {detector.published_name}")
        print(f"  Threshold: {detector.conf_threshold}")
        
        # Test with image if provided
        if len(sys.argv) > 1:
            test_image = sys.argv[1]
            if os.path.exists(test_image):
                print(f"\n✓ Testing with image: {test_image}")
                results = detector.detect_bricks(test_image)
                print(f"✓ Detected {len(results)} bricks:")
                for i, brick in enumerate(results[:5], 1):
                    print(f"   {i}. {brick['name']} ({brick['color']}) @ {brick['confidence']:.1%}")
                if len(results) > 5:
                    print(f"   ... and {len(results)-5} more")
        
        print("\n✅ Azure detector working!\n")
        return True
        
    except Exception as e:
        print(f"\n❌ Azure detector test failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_flask_api():
    """Test Flask API endpoints"""
    print("=" * 70)
    print("3. TESTING FLASK API")
    print("=" * 70)
    
    base_url = "http://localhost:5000"
    
    # Test health endpoint
    try:
        response = requests.get(f"{base_url}/api/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✓ Health check: {data.get('status')}")
            print(f"  Detector: {data.get('detector')}")
            print(f"  Version: {data.get('version')}")
        else:
            print(f"✗ Health check failed: {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print("⚠️  Flask server not running")
        print("   Start it with: python app.py")
        return False
    except Exception as e:
        print(f"✗ Health check error: {e}")
        return False
    
    # Test upload endpoint with image if provided
    if len(sys.argv) > 1:
        test_image = sys.argv[1]
        if os.path.exists(test_image):
            try:
                print(f"\n✓ Testing upload with: {test_image}")
                with open(test_image, 'rb') as f:
                    files = {'file': (os.path.basename(test_image), f, 'image/jpeg')}
                    response = requests.post(f"{base_url}/api/upload", files=files, timeout=30)
                
                if response.status_code == 200:
                    data = response.json()
                    print(f"✓ Upload successful!")
                    print(f"  Bricks detected: {data.get('bricks_detected')}")
                    print(f"  Detector used: {data.get('detector')}")
                    
                    # Show first few results
                    results = data.get('results', [])
                    for i, brick in enumerate(results[:3], 1):
                        print(f"   {i}. {brick['name']} ({brick['color']}) @ {brick['confidence']:.1%}")
                    if len(results) > 3:
                        print(f"   ... and {len(results)-3} more")
                else:
                    print(f"✗ Upload failed: {response.status_code}")
                    print(f"  Response: {response.text}")
                    return False
            except Exception as e:
                print(f"✗ Upload test error: {e}")
                return False
    
    print("\n✅ Flask API working!\n")
    return True

def main():
    """Run all tests"""
    print("\n" + "=" * 70)
    print("AZURE CUSTOM VISION INTEGRATION TEST SUITE")
    print("=" * 70 + "\n")
    
    # Test 1: Environment
    if not test_env_variables():
        print("\n❌ Environment test failed. Fix .env file and try again.")
        sys.exit(1)
    
    # Test 2: Azure Detector
    if not test_azure_detector():
        print("\n❌ Azure detector test failed.")
        sys.exit(1)
    
    # Test 3: Flask API (optional)
    print("Testing Flask API (optional)...")
    test_flask_api()  # Don't fail if server not running
    
    # Summary
    print("=" * 70)
    print("✅ ALL CORE TESTS PASSED!")
    print("=" * 70)
    print("\nYour Azure integration is ready!")
    print("\nNext steps:")
    print("  1. Start Flask server: python app.py")
    print("  2. Test with frontend")
    print("  3. Share with your team")
    print("\n" + "=" * 70 + "\n")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print("Usage: python test_azure.py [image_path]")
        print("\nTests Azure Custom Vision integration")
        print("Optionally provide test image path to run detection")
        sys.exit(0)
    
    main()

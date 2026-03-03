"""
Frontend API Service Validation
Tests that the Dart API service layer would work correctly with the backend
"""

import requests
import json
import time


def test_flutter_api_contract():
    """Simulate Flutter API calls to ensure compatibility"""
    BASE_URL = "http://localhost:5000/api"
    print("\n" + "="*70)
    print("FRONTEND API CONTRACT VALIDATION".center(70))
    print("="*70 + "\n")
    
    tests_passed = 0
    tests_total = 0
    
    # Test 1: Health check (used by ProfileScreen)
    print("1. Testing /health endpoint (ProfileScreen)")
    tests_total += 1
    try:
        resp = requests.get(f"{BASE_URL}/health")
        assert resp.status_code == 200
        data = resp.json()
        # Flutter code expects these fields
        assert "status" in data
        assert "pinecone_status" in data
        assert "detector_status" in data
        print("   [PASS] Health endpoint matches Flutter expectations")
        tests_passed += 1
    except Exception as e:
        print(f"   [FAIL] Failed: {e}")
    
    # Test 2: Upload image (used by ScanScreen)
    print("2. Testing /upload endpoint (ScanScreen)")
    tests_total += 1
    try:
        from PIL import Image
        import io
        
        img = Image.new('RGB', (100, 100), color='blue')
        img_bytes = io.BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        
        files = {'file': ('test.png', img_bytes, 'image/png')}
        resp = requests.post(f"{BASE_URL}/upload", files=files)
        assert resp.status_code == 200
        data = resp.json()
        # Flutter expects these fields for ScanScreen
        assert data.get("success") == True
        assert "results" in data
        assert isinstance(data["results"], list)
        if len(data["results"]) > 0:
            brick = data["results"][0]
            assert "id" in brick
            assert "name" in brick
            assert "color" in brick
            assert "quantity" in brick
        print("   [PASS] Upload endpoint matches Flutter expectations (ScanScreen)")
        tests_passed += 1
    except Exception as e:
        print(f"   [FAIL] Failed: {e}")
    
    # Test 3: Inventory GET (used by InventoryScreen)
    print("3. Testing GET /inventory endpoint (InventoryScreen)")
    tests_total += 1
    try:
        resp = requests.get(f"{BASE_URL}/inventory")
        assert resp.status_code == 200
        data = resp.json()
        # Flutter InventoryScreen expects these fields
        assert data.get("success") == True
        assert "inventory" in data
        assert isinstance(data["inventory"], list)
        if len(data["inventory"]) > 0:
            item = data["inventory"][0]
            assert "id" in item or "brick_id" in item
            assert "name" in item
            assert "color" in item
            assert "quantity" in item
        print("   [PASS] Inventory GET matches Flutter expectations (InventoryScreen)")
        tests_passed += 1
    except Exception as e:
        print(f"   [FAIL] Failed: {e}")
    
    # Test 4: Recommendations (used by RecommendationsScreen)
    print("4. Testing /recommendations endpoint (RecommendationsScreen)")
    tests_total += 1
    try:
        resp = requests.get(f"{BASE_URL}/recommendations?limit=5")
        assert resp.status_code == 200
        data = resp.json()
        # Flutter RecommendationsScreen expects these fields
        assert "recommendations" in data
        assert isinstance(data["recommendations"], list)
        if len(data["recommendations"]) > 0:
            set_rec = data["recommendations"][0]
            assert "set_id" in set_rec or "name" in set_rec
            assert "name" in set_rec
            assert "completion_percentage" in set_rec
            assert "missing_pieces" in set_rec
        print("   [PASS] Recommendations matches Flutter expectations (RecommendationsScreen)")
        tests_passed += 1
    except Exception as e:
        print(f"   [FAIL] Failed: {e}")
    
    # Test 5: Brick metadata (used by various screens)
    print("5. Testing /brick/{id} endpoint")
    tests_total += 1
    try:
        resp = requests.get(f"{BASE_URL}/brick/3001")
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        assert "brick" in data
        brick = data["brick"]
        assert "id" in brick
        assert "official_name" in brick
        print("   [PASS] Brick metadata endpoint matches Flutter expectations")
        tests_passed += 1
    except Exception as e:
        print(f"   [FAIL] Failed: {e}")
    
    # Test 6: Set metadata
    print("6. Testing /set/{id} endpoint")
    tests_total += 1
    try:
        resp = requests.get(f"{BASE_URL}/set/10698")
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        assert "set" in data
        set_data = data["set"]
        assert "set_id" in set_data
        assert "name" in set_data
        print("   [PASS] Set metadata endpoint matches Flutter expectations")
        tests_passed += 1
    except Exception as e:
        print(f"   [FAIL] Failed: {e}")
    
    # Test 7: Base64 upload (web platform)
    print("7. Testing base64 image upload (web platform)")
    tests_total += 1
    try:
        from PIL import Image
        import io
        import base64
        
        img = Image.new('RGB', (100, 100), color='green')
        img_bytes = io.BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        b64 = base64.b64encode(img_bytes.read()).decode('utf-8')
        
        payload = {"image": f"data:image/png;base64,{b64}"}
        resp = requests.post(f"{BASE_URL}/upload", json=payload)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        assert "results" in data
        print("   [PASS] Base64 upload works (web platform support)")
        tests_passed += 1
    except Exception as e:
        print(f"   [FAIL] Failed: {e}")
    
    # Test 8: Error codes match Flutter expectations
    print("8. Testing error handling")
    tests_total += 1
    try:
        # Should return 404 for non-existent brick
        resp = requests.get(f"{BASE_URL}/brick/99999")
        assert resp.status_code == 404
        data = resp.json()
        assert data.get("success") == False
        
        # Should return 400 for bad inventory POST
        resp = requests.post(f"{BASE_URL}/inventory", json={})
        assert resp.status_code == 400
        data = resp.json()
        assert data.get("success") == False
        
        print("   [PASS] Error responses match Flutter expectations")
        tests_passed += 1
    except Exception as e:
        print(f"   [FAIL] Failed: {e}")
    
    # Summary
    print("\n" + "="*70)
    print(f"FRONTEND API VALIDATION: {tests_passed}/{tests_total} tests passed")
    print("="*70)
    
    if tests_passed == tests_total:
        print("[PASS] Frontend API service will work correctly with backend")
        return 0
    else:
        print(f"[FAIL] {tests_total - tests_passed} test(s) failed")
        return 1


if __name__ == "__main__":
    import sys
    sys.exit(test_flutter_api_contract())

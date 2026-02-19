#!/usr/bin/env python3
"""
Integration test for Lego Brick Counter (Backend + Frontend API contract)
Tests all major endpoints and validates BE/FE compatibility
"""

import requests
import json
import time
import base64
from pathlib import Path

BASE_URL = "http://localhost:5000/api"
TIMEOUT = 10

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def print_success(msg):
    print(f"{Colors.GREEN}✓ {msg}{Colors.RESET}")

def print_error(msg):
    print(f"{Colors.RED}✗ {msg}{Colors.RESET}")

def print_info(msg):
    print(f"{Colors.BLUE}ℹ {msg}{Colors.RESET}")

def print_section(title):
    print(f"\n{Colors.YELLOW}{'='*60}")
    print(f"{title:^60}")
    print(f"{'='*60}{Colors.RESET}\n")

def test_health():
    """Test 1: Health endpoint"""
    print_section("TEST 1: Health Check")
    try:
        resp = requests.get(f"{BASE_URL}/health", timeout=TIMEOUT)
        assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
        data = resp.json()
        assert data.get("status") == "healthy", "Status is not healthy"
        assert data.get("version") == "2.0.0", "Version mismatch"
        assert "detector_status" in data, "Missing detector_status"
        assert "pinecone_status" in data, "Missing pinecone_status"
        print_success("Health endpoint responds with correct schema")
        print_info(f"Backend: {data['status']}, Detector: {data['detector_status']}, Pinecone: {data['pinecone_status']}")
        return True
    except Exception as e:
        print_error(f"Health check failed: {e}")
        return False

def test_api_metadata():
    """Test 2: API version endpoint"""
    print_section("TEST 2: API Metadata")
    try:
        resp = requests.get(f"{BASE_URL}/version", timeout=TIMEOUT)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("version") == "2.0.0"
        endpoints = data.get("endpoints", [])
        expected = ["/api/health", "/api/upload", "/api/inventory", "/api/recommendations"]
        for e in expected:
            assert any(e in ep for ep in endpoints), f"Missing endpoint: {e}"
        print_success("API metadata endpoint returns correct version and endpoints")
        return True
    except Exception as e:
        print_error(f"API metadata test failed: {e}")
        return False

def test_brick_metadata():
    """Test 3: Brick metadata lookup"""
    print_section("TEST 3: Brick Metadata")
    try:
        resp = requests.get(f"{BASE_URL}/brick/3001", timeout=TIMEOUT)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        brick = data.get("brick", {})
        assert brick.get("id") == "3001"
        assert brick.get("official_name") == "Brick 2x4"
        assert "colors_available" in brick
        print_success("Brick metadata lookup works (3001 = 2x4 Brick)")
        return True
    except Exception as e:
        print_error(f"Brick metadata test failed: {e}")
        return False

def test_set_metadata():
    """Test 4: Set metadata lookup"""
    print_section("TEST 4: Set Metadata")
    try:
        resp = requests.get(f"{BASE_URL}/set/10698", timeout=TIMEOUT)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        lego_set = data.get("set", {})
        assert lego_set.get("set_id") == "10698"
        assert lego_set.get("name") == "Classic Creative Brick Box"
        assert lego_set.get("pieces") == 790
        print_success("Set metadata lookup works (10698 = Classic Creative Brick Box)")
        return True
    except Exception as e:
        print_error(f"Set metadata test failed: {e}")
        return False

def test_inventory_get():
    """Test 5: Get inventory"""
    print_section("TEST 5: Inventory - GET")
    try:
        resp = requests.get(f"{BASE_URL}/inventory", timeout=TIMEOUT)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        assert "inventory" in data
        assert "summary" in data
        summary = data["summary"]
        assert "total_bricks" in summary
        assert "unique_colors" in summary
        assert "unique_types" in summary
        print_success(f"Inventory retrieved: {len(data['inventory'])} types, {summary['total_bricks']} total bricks")
        return True
    except Exception as e:
        print_error(f"Inventory GET test failed: {e}")
        return False

def test_inventory_post():
    """Test 6: Add to inventory"""
    print_section("TEST 6: Inventory - POST (Add)")
    try:
        bricks = [
            {"id": "3001", "name": "2x4 Brick", "color": "Red", "quantity": 5},
            {"id": "3003", "name": "2x2 Brick", "color": "Blue", "quantity": 3},
        ]
        resp = requests.post(
            f"{BASE_URL}/inventory",
            json={"bricks": bricks},
            headers={"X-User-Id": "test_user"},
            timeout=TIMEOUT
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        assert len(data.get("added", [])) == 2
        print_success("Added 2 brick types to inventory")
        return True
    except Exception as e:
        print_error(f"Inventory POST test failed: {e}")
        return False

def test_recommendations():
    """Test 7: Get recommendations"""
    print_section("TEST 7: Recommendations")
    try:
        resp = requests.get(f"{BASE_URL}/recommendations?limit=3", timeout=TIMEOUT)
        assert resp.status_code == 200
        data = resp.json()
        assert "recommendations" in data
        recs = data["recommendations"]
        assert len(recs) > 0
        rec = recs[0]
        assert "set_id" in rec
        assert "name" in rec
        assert "completion_percentage" in rec
        assert "missing_pieces" in rec
        print_success(f"Recommendations retrieved: {len(recs)} sets, top: {rec['name']} ({rec['completion_percentage']}%)")
        return True
    except Exception as e:
        print_error(f"Recommendations test failed: {e}")
        return False

def test_pinecone_stats():
    """Test 8: Pinecone stats"""
    print_section("TEST 8: Pinecone Stats")
    try:
        resp = requests.get(f"{BASE_URL}/pinecone/stats", timeout=TIMEOUT)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        stats = data.get("pinecone", {})
        if stats.get("enabled"):
            print_success(f"Pinecone connected: {stats.get('total_vectors', 0)} vectors")
        else:
            print_info("Pinecone not configured (local-only mode) - this is OK")
        return True
    except Exception as e:
        print_error(f"Pinecone stats test failed: {e}")
        return False

def test_upload_with_mock_image():
    """Test 9: Image upload with brick-shaped rectangles"""
    print_section("TEST 9: Image Upload + Detection")
    try:
        from PIL import Image, ImageDraw
        import io
        
        # Create an image with brick-shaped colored rectangles
        img = Image.new('RGB', (640, 640), color=(220, 220, 220))
        draw = ImageDraw.Draw(img)
        # Red 2x4-ish rectangle
        draw.rectangle([50, 50, 210, 130], fill=(230, 0, 0))
        # Blue 2x2-ish square
        draw.rectangle([300, 200, 380, 280], fill=(0, 0, 230))
        # Yellow elongated
        draw.rectangle([400, 80, 560, 130], fill=(230, 230, 0))
        # Green brick
        draw.rectangle([100, 350, 260, 430], fill=(0, 180, 0))

        img_bytes = io.BytesIO()
        img.save(img_bytes, format='PNG')
        img_bytes.seek(0)
        
        files = {'file': ('test.png', img_bytes, 'image/png')}
        resp = requests.post(f"{BASE_URL}/upload", files=files, timeout=TIMEOUT)
        assert resp.status_code == 200
        data = resp.json()
        assert data.get("success") == True
        assert "bricks_detected" in data
        assert "results" in data
        n = data['bricks_detected']
        print_success(f"Image uploaded, detected {n} brick(s)")
        if n > 0:
            for b in data['results']:
                print_info(f"  {b['name']} ({b['color']}) conf={b['confidence']:.0%}")
        else:
            print_info("No bricks detected — model may need real photos for best results")
        return True
    except Exception as e:
        print_error(f"Image upload test failed: {e}")
        return False

def test_similar_bricks():
    """Test 10: Similarity search (Pinecone)"""
    print_section("TEST 10: Similarity Search")
    try:
        brick = {
            "id": "3001",
            "name": "2x4 Brick",
            "color": "Red",
            "quantity": 1,
            "confidence": 0.95
        }
        resp = requests.post(
            f"{BASE_URL}/similar",
            json={"brick": brick, "top_k": 5},
            timeout=TIMEOUT
        )
        # This may fail if Pinecone is not configured - that's OK for testing
        if resp.status_code == 200:
            data = resp.json()
            if data.get("success"):
                results = data.get("similar_bricks", [])
                print_success(f"Similarity search returned {len(results)} results")
            else:
                print_info("Pinecone similarity search not available (local-only mode)")
        elif resp.status_code == 503:
            print_info("Pinecone not configured - expected for local dev")
        else:
            raise Exception(f"Unexpected status code: {resp.status_code}")
        return True
    except Exception as e:
        print_error(f"Similarity search test failed: {e}")
        return False

def test_error_handling():
    """Test 11: Error handling"""
    print_section("TEST 11: Error Handling")
    try:
        # Test 404
        resp = requests.get(f"{BASE_URL}/brick/9999", timeout=TIMEOUT)
        assert resp.status_code == 404
        print_success("404 error handling works")
        
        # Test 400
        resp = requests.post(f"{BASE_URL}/inventory", json={}, timeout=TIMEOUT)
        assert resp.status_code == 400
        print_success("400 error handling works")
        
        return True
    except Exception as e:
        print_error(f"Error handling test failed: {e}")
        return False

def main():
    print(f"\n{Colors.BLUE}")
    print("╔" + "═"*58 + "╗")
    print("║" + "LEGO BRICK COUNTER - INTEGRATION TEST".center(58) + "║")
    print("║" + "Testing Backend ↔ Frontend Compatibility".center(58) + "║")
    print("╚" + "═"*58 + "╝")
    print(Colors.RESET)
    
    print_info(f"Target: {BASE_URL}")
    time.sleep(1)
    
    tests = [
        ("Backend Health", test_health),
        ("API Metadata", test_api_metadata),
        ("Brick Metadata", test_brick_metadata),
        ("Set Metadata", test_set_metadata),
        ("Inventory GET", test_inventory_get),
        ("Inventory POST", test_inventory_post),
        ("Recommendations", test_recommendations),
        ("Pinecone Stats", test_pinecone_stats),
        ("Image Upload", test_upload_with_mock_image),
        ("Similarity Search", test_similar_bricks),
        ("Error Handling", test_error_handling),
    ]
    
    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print_error(f"Unexpected error in {name}: {e}")
            results.append((name, False))
        time.sleep(0.5)
    
    # Summary
    print_section("TEST RESULTS SUMMARY")
    passed = sum(1 for _, r in results if r)
    total = len(results)
    
    for name, result in results:
        status = f"{Colors.GREEN}PASS{Colors.RESET}" if result else f"{Colors.RED}FAIL{Colors.RESET}"
        print(f"  {name:.<45} {status}")
    
    print()
    if passed == total:
        print(f"{Colors.GREEN}✓ ALL TESTS PASSED ({passed}/{total}){Colors.RESET}")
        return 0
    else:
        print(f"{Colors.RED}✗ SOME TESTS FAILED ({passed}/{total}){Colors.RESET}")
        return 1

if __name__ == "__main__":
    import sys
    sys.exit(main())

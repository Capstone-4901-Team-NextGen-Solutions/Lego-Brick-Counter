import requests
import json

base = "http://localhost:5000"

print("=== TESTING BACKEND ENDPOINTS ===\n")

# 1. Health check
print("1. Health Check:")
try:
    r = requests.get(f"{base}/api/health")
    print(f"   Status: {r.status_code}")
    print(f"   Response: {r.json()}\n")
except Exception as e:
    print(f"   Error: {e}\n")

# 2. Register a test user
print("2. Register Test User:")
register_data = {
    "email": "test@example.com",
    "password": "test123",
    "username": "TestUser"
}
r = requests.post(f"{base}/api/auth/register", json=register_data)
print(f"   Status: {r.status_code}")
if r.status_code == 201:
    print("   User created successfully")
    token = r.json().get('token')
elif r.status_code == 400:
    print("   User may already exist, trying login...")
    r = requests.post(f"{base}/api/auth/login", 
                     json={"email": "test@example.com", "password": "test123"})
    if r.status_code == 200:
        token = r.json().get('token')
        print("   Login successful")
    else:
        print(f"   Login failed: {r.text}")
        exit()
else:
    print(f"   Failed: {r.text}")
    exit()

print(f"   Token obtained: {token[:50]}...\n")

# 3. Test recommendations endpoint
print("3. Recommendations Endpoint:")
headers = {"Authorization": f"Bearer {token}"}
r = requests.get(f"{base}/api/recommendations", headers=headers)
print(f"   Status: {r.status_code}")
if r.status_code == 200:
    data = r.json()
    print(f"   Response keys: {list(data.keys())}")
    print(f"   Recommendations count: {len(data.get('recommendations', []))}")
    if data.get('recommendations'):
        print(f"   First recommendation: {data['recommendations'][0].get('name')}")
else:
    print(f"   Error response: {r.text}")

# 4. Test inventory endpoint
print("\n4. Inventory Endpoint:")
r = requests.get(f"{base}/api/inventory", headers=headers)
print(f"   Status: {r.status_code}")
if r.status_code == 200:
    data = r.json()
    print(f"   Inventory count: {data.get('count', 0)}")

# 5. Test scan history endpoint
print("\n5. Scan History Endpoint:")
r = requests.get(f"{base}/api/scan-history", headers=headers)
print(f"   Status: {r.status_code}")
if r.status_code == 200:
    data = r.json()
    print(f"   Scan count: {data.get('count', 0)}")

print("\n=== TEST COMPLETE ===")
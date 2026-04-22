# save as test_with_inventory.py
import requests
import json

base = "http://localhost:5000"

# Login first
print("Logging in...")
login_data = {"email": "test@example.com", "password": "test123"}
r = requests.post(f"{base}/api/auth/login", json=login_data)
token = r.json()['token']
headers = {"Authorization": f"Bearer {token}"}
print("Logged in successfully!")

# Add some bricks to inventory
print("\nAdding bricks to inventory...")
bricks_data = {
    "bricks": [
        {"id": "3001", "name": "Brick 2x4", "color": "Red", "quantity": 5},
        {"id": "3003", "name": "Brick 2x2", "color": "Blue", "quantity": 3},
        {"id": "3023", "name": "Plate 1x2", "color": "Yellow", "quantity": 10},
    ]
}
r = requests.post(f"{base}/api/inventory", json=bricks_data, headers=headers)
print(f"Add inventory response: {r.json()}")

# Check inventory
print("\nCurrent inventory:")
r = requests.get(f"{base}/api/inventory", headers=headers)
inventory = r.json()
print(f"Total bricks: {inventory.get('summary', {}).get('total_bricks', 0)}")
print(f"Unique types: {inventory.get('summary', {}).get('unique_types', 0)}")

# Get recommendations
print("\nRecommendations:")
r = requests.get(f"{base}/api/recommendations", headers=headers)
recs = r.json()
print(f"Found {len(recs.get('recommendations', []))} recommendations")
for rec in recs.get('recommendations', []):
    print(f"  - {rec['name']}: {rec['completion_percentage']}% complete")

print("\n=== Done ===")
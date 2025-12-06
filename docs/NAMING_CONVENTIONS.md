# Naming Conventions Guide
## Lego Brick Counter Project

## Purpose
This document ensures consistency across the codebase for better maintainability and collaboration between frontend and backend teams.

---

## Project Structure

### Backend (Python/Flask)
```text
backend/
├── app.py                    # Main Flask application
├── brick_detector.py         # ONNX model handler
├── requirements.txt          # Python dependencies
├── test_api.py              # Unit tests
├── uploads/                 # Uploaded images (gitignored)
├── docs/                    # Documentation
│   ├── API_CONTRACT.md
│   └── NAMING_CONVENTIONS.md
└── class_names.txt          # Model class names
```

### Frontend (Flutter/Dart)
```text
frontend/
├── lib/
│   ├── main.dart            # Application entry point
│   └── services/
│       └── api_service.dart # API communication
├── pubspec.yaml             # Dependencies
└── assets/                  # Images, fonts
```

---

## Python/Flask Conventions

### File Names
- **Use**: `snake_case.py`
- **Examples**: 
  - `brick_detector.py` 
  - `app.py` 
  - `BrickDetector.py`  (no PascalCase for files)

### Variables and Functions
- **Use**: `snake_case`
- **Examples**:
```python
# Variables
image_path = "uploads/image.jpg"
brick_count = 15
is_processing = False
detection_results = []

# Functions
def process_image_for_bricks(image_path):
    pass

def aggregate_brick_detections(raw_detections):
    pass

def save_to_database(brick_data):
    pass
```

### Classes
- **Use**: `PascalCase`
- **Examples**:
```python
class BrickDetector:
    pass

class LegoBrick:
    pass
```

### Constants
- **Use**: `UPPER_SNAKE_CASE`
- **Examples**:
```python
MAX_CONTENT_LENGTH = 16 * 1024 * 1024
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
```

### Flask Routes
- **URL Paths**: `kebab-case`
- **Examples**:
```python
@app.route('/api/upload', methods=['POST'])
@app.route('/api/analyze-photo', methods=['POST'])
@app.route('/api/brick/<brick_id>', methods=['GET'])
```

---

## Flutter/Dart Conventions

### File Names
- **Use**: `snake_case.dart`
- **Examples**:
  - `main.dart` 
  - `api_service.dart` 

### Variables and Parameters
- **Use**: `camelCase`
- **Examples**:
```dart
List<LegoBrick> scannedBricks = [];
bool isProcessing = false;
String? errorMessage;

Widget buildBrickCard(LegoBrick brick) {}
Future<void> processImage(XFile imageFile) async {}
```

### Private Members
- **Use**: `_camelCase` (underscore prefix)
- **Examples**:
```dart
class _ScanScreenState extends State<ScanScreen> {
  final List<LegoBrick> _scannedBricks = [];
  bool _isProcessing = false;
  
  void _takePhoto() async {}
  Widget _buildBrickCard(LegoBrick brick) {}
}
```

### Classes and Types
- **Use**: `PascalCase`
- **Examples**:
```dart
class LegoApp extends StatelessWidget {}
class ScanScreen extends StatefulWidget {}
class LegoBrick {}
class LegoSet {}
```

### API Service Methods
- **Use**: `camelCase` matching backend endpoints
- **Examples**:
```dart
class ApiService {
  static Future<Map<String, dynamic>> uploadImage(XFile imageFile) async {}
  static Future<Map<String, dynamic>> getInventory() async {}
  static Future<Map<String, dynamic>> getRecommendations() async {}
}
```

---

## API Data Formats

### Request/Response Fields
- **Use**: `snake_case` in JSON
- **Examples**:
```json
{
  "success": true,
  "bricks_detected": 15,
  "results": [
    {
      "id": "3001",
      "name": "2x4 Brick",
      "color": "Red",
      "quantity": 3,
      "confidence": 0.95
    }
  ]
}
```

### Error Responses
- **Use**: Consistent format
- **Examples**:
```json
{
  "success": false,
  "error": "File upload failed",
  "details": "Image exceeds maximum size"
}
```

---

## Git Conventions

### Branch Naming
- `feature/description`
- `fix/description`
- `hotfix/description`

**Examples**:
```
feature/add-color-detection
fix/image-upload-error
hotfix/critical-fix
```

### Commit Messages
**Format**: `type(scope): description`

**Examples**:
```
feat(api): add brick metadata endpoint
fix(upload): resolve image processing error
docs: update API contract
test: add unit tests
```

---

## Checklist for Code Reviews

### Backend
- [ ] File names: `snake_case.py`
- [ ] Variables: `snake_case`
- [ ] Classes: `PascalCase`
- [ ] Routes: `kebab-case`
- [ ] JSON: `snake_case`

### Frontend
- [ ] Variables: `camelCase`
- [ ] Private: `_camelCase`
- [ ] Classes: `PascalCase`
- [ ] API calls match endpoints

### General
- [ ] Commit messages follow convention
- [ ] Branch names follow pattern
- [ ] API matches contract

---

## Quick Reference

| Language | Files | Variables | Classes | Constants | URLs |
|----------|-------|-----------|---------|-----------|------|
| Python | `snake_case.py` | `snake_case` | `PascalCase` | `UPPER_CASE` | `kebab-case` |
| Dart | `snake_case.dart` | `camelCase` | `PascalCase` | `UPPER_CASE` | N/A |
| JSON | N/A | `snake_case` | N/A | N/A | N/A |

**Rule**: Follow existing patterns in each file.

---

**Last Updated**: 2024-01-15  
**Maintainer**: Backend Team
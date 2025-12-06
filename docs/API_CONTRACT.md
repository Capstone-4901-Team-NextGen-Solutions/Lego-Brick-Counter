# Lego Brick Counter API Contract v1.0

## Overview
This document defines the API contract between the Flask backend and Flutter frontend for the Lego Brick Counter application.

## Base URLs
- **Development**: `http://localhost:5000/api`
- **Production**: `https://api.legobrickcounter.com/api` (example)

## Authentication
Currently no authentication required for development. Future versions will implement JWT tokens.

## Image Requirements
| Requirement | Specification |
|-------------|---------------|
| Max File Size | 16MB |
| Supported Formats | JPG, JPEG, PNG, GIF |
| Max Dimensions | 4096 × 4096 pixels |
| Color Space | RGB recommended |

---

## API Endpoints

### 1. Health Check
**Endpoint**: `GET /api/health`

**Description**: Check if API is running and detector is initialized.

**Response (200 OK)**:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "detector_status": "initialized"
}
```

---

### 2. Upload Image
**Endpoint**: `POST /api/upload`

**Description**: Upload image for brick detection. Accepts both file upload and base64.

#### Request Formats:

**Option A: Multipart Form Data**
```text
POST /api/upload HTTP/1.1
Content-Type: multipart/form-data

file: [binary image data]
```

**Option B: JSON with Base64**
```text
POST /api/upload HTTP/1.1
Content-Type: application/json

{
  "image": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ..."
}
```

#### Response (200 OK - Success):
```json
{
  "success": true,
  "filename": "lego_scan_20240115_103000.jpg",
  "bricks_detected": 15,
  "results": [
    {
      "id": "3001",
      "name": "2x4 Brick",
      "color": "Red",
      "quantity": 3,
      "confidence": 0.95,
      "bbox": [100, 150, 80, 40]
    },
    {
      "id": "3003",
      "name": "2x2 Brick",
      "color": "Blue",
      "quantity": 2,
      "confidence": 0.87,
      "bbox": [200, 250, 40, 40]
    }
  ],
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### Error Responses:
- **400 Bad Request**: No file or image data provided
- **415 Unsupported Media Type**: Invalid file format
- **500 Internal Server Error**: Processing failed

---

### 3. 🔍 Enhanced Photo Analysis
**Endpoint**: `POST /api/analyze-photo`

**Description**: Advanced analysis with detailed metadata and statistics.

#### Request:
```text
POST /api/analyze-photo HTTP/1.1
Content-Type: multipart/form-data

file: [binary image data]
```

#### Response (200 OK):
```json
{
  "success": true,
  "analysis_id": "ana_20240115_103000",
  "image_metadata": {
    "dimensions": {"width": 1920, "height": 1080},
    "format": "JPEG",
    "size_kb": 1245.5,
    "color_mode": "RGB"
  },
  "detection_summary": {
    "total_bricks": 15,
    "unique_types": 5,
    "detection_time_ms": 1250.5,
    "total_processing_time_ms": 1850.2
  },
  "bricks": [
    {
      "id": "3001",
      "name": "2x4 Brick",
      "color": "Red",
      "quantity": 3,
      "confidence": 0.95
    }
  ],
  "color_distribution": {
    "Red": 5,
    "Blue": 3,
    "Yellow": 7
  },
  "suggested_sets": [
    {
      "set_id": "10698",
      "name": "Classic Creative Brick Box",
      "completion_percentage": 85,
      "missing_pieces": 12,
      "total_pieces": 790,
      "difficulty": "beginner",
      "image_url": "https://example.com/sets/10698.jpg"
    }
  ],
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## 4. Inventory Management

### 4.1 Get Inventory
**Endpoint**: `GET /api/inventory`

**Description**: Get user's brick inventory with optional filtering.

#### Query Parameters:
- `color` (optional): Filter by color name
- `min_quantity` (optional): Minimum quantity filter
- `limit` (optional): Limit results (default: 50)

#### Response (200 OK):
```json
{
  "success": true,
  "count": 5,
  "inventory": [
    {
      "id": "3001",
      "name": "2x4 Brick",
      "color": "Red",
      "quantity": 15,
      "last_updated": "2024-01-15T10:30:00Z"
    },
    {
      "id": "3003",
      "name": "2x2 Brick",
      "color": "Blue",
      "quantity": 12,
      "last_updated": "2024-01-15T10:30:00Z"
    }
  ],
  "summary": {
    "total_bricks": 58,
    "unique_colors": 4,
    "unique_types": 5
  }
}
```

---

### 4.2 Add to Inventory
**Endpoint**: `POST /api/inventory`

**Description**: Add bricks to inventory.

#### Request:
```json
{
  "bricks": [
    {
      "id": "3001",
      "name": "2x4 Brick",
      "color": "Red",
      "quantity": 5,
      "action": "add"
    }
  ]
}
```

#### Response (200 OK):
```json
{
  "success": true,
  "message": "Added 5 brick(s) to inventory",
  "added": [
    {
      "id": "3001",
      "name": "2x4 Brick",
      "color": "Red",
      "quantity": 5
    }
  ],
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

### 4.3 Update Inventory
**Endpoint**: `PUT /api/inventory`

**Description**: Update brick quantities in inventory.

#### Request:
```json
{
  "updates": [
    {
      "id": "3001",
      "quantity": 20,
      "action": "set"
    }
  ]
}
```

#### Response (200 OK):
```json
{
  "success": true,
  "message": "Updated 1 brick(s)",
  "updates": [
    {
      "id": "3001",
      "old_quantity": 15,
      "new_quantity": 20
    }
  ]
}
```

---

### 4.4 Clear Inventory
**Endpoint**: `DELETE /api/inventory`

**Description**: Clear entire inventory or specific bricks.

#### Query Parameters:
- `brick_id` (optional): Specific brick ID to delete (can be multiple)
- `confirm` (required for full clear): Must be "true" to clear all

#### Response (200 OK - Clear specific):
```json
{
  "success": true,
  "message": "Deleted 2 brick type(s) from inventory",
  "deleted_ids": ["3001", "3003"]
}
```

#### Response (200 OK - Clear all):
```json
{
  "success": true,
  "message": "Inventory cleared successfully"
}
```

---

### 5. Get Recommendations
**Endpoint**: `GET /api/recommendations`

**Description**: Get Lego set recommendations based on current inventory.

#### Query Parameters:
- `limit` (optional): Number of recommendations (default: 5, max: 20)

#### Response (200 OK):
```json
{
  "recommendations": [
    {
      "set_id": "10698",
      "name": "Classic Creative Brick Box",
      "completion_percentage": 85,
      "missing_pieces": 12,
      "total_pieces": 790,
      "image_url": "https://example.com/sets/10698.jpg",
      "estimated_build_time": "2-3 hours",
      "difficulty": "beginner"
    },
    {
      "set_id": "31134",
      "name": "Space Rocket",
      "completion_percentage": 72,
      "missing_pieces": 23,
      "total_pieces": 837,
      "image_url": "https://example.com/sets/31134.jpg",
      "estimated_build_time": "3-4 hours",
      "difficulty": "intermediate"
    }
  ]
}
```

---

### 6. Brick Metadata
**Endpoint**: `GET /api/brick/{brick_id}`

**Description**: Get detailed metadata for a specific Lego brick.

#### Path Parameters:
- `brick_id`: Lego part number (e.g., "3001")

#### Response (200 OK):
```json
{
  "success": true,
  "brick": {
    "id": "3001",
    "official_name": "Brick 2x4",
    "alternate_names": ["2x4 Brick", "Basic Brick"],
    "colors_available": ["Red", "Blue", "Yellow", "Green", "Black", "White"],
    "first_released": "1958",
    "weight_g": 2.32,
    "dimensions_mm": {
      "length": 31.8,
      "width": 15.9,
      "height": 9.6
    },
    "sets_contained_in": ["10698", "11011", "10717"],
    "category": "Basic Bricks",
    "material": "ABS Plastic",
    "description": "The classic 2x4 Lego brick, first produced in 1958."
  }
}
```

#### Error Response (404 Not Found):
```json
{
  "success": false,
  "error": "Brick ID '9999' not found"
}
```

---

### 7. Set Metadata
**Endpoint**: `GET /api/set/{set_id}`

**Description**: Get detailed metadata for a Lego set.

#### Path Parameters:
- `set_id`: Lego set number (e.g., "10698")

#### Response (200 OK):
```json
{
  "success": true,
  "set": {
    "name": "Classic Creative Brick Box",
    "year": 2023,
    "pieces": 790,
    "minifigures": 0,
    "age_range": "4+",
    "theme": "Classic",
    "price_usd": 49.99,
    "weight_kg": 1.2,
    "dimensions_cm": {
      "length": 26.2,
      "width": 14.1,
      "height": 7.1
    },
    "bricks_included": [
      {
        "id": "3001",
        "quantity": 12,
        "color": "Red"
      },
      {
        "id": "3003",
        "quantity": 10,
        "color": "Yellow"
      }
    ],
    "build_time_minutes": 120,
    "difficulty": "Beginner",
    "description": "A creative brick box with ideas for multiple builds."
  }
}
```

---

## Error Responses

### Standard Error Format
```json
{
  "success": false,
  "error": "Human readable error message",
  "details": "Technical details (optional)",
  "code": "ERROR_CODE (optional)"
}
```

### HTTP Status Codes

#### 400 Bad Request
```json
{
  "success": false,
  "error": "Invalid input or missing parameters",
  "details": "No file provided in upload request"
}
```

#### 404 Not Found
```json
{
  "success": false,
  "error": "Resource not found",
  "details": "Brick ID '9999' not found in database"
}
```

#### 413 Payload Too Large
```json
{
  "success": false,
  "error": "File too large",
  "details": "Image exceeds 16MB limit. Current size: 20MB",
  "code": "FILE_TOO_LARGE"
}
```

#### 415 Unsupported Media Type
```json
{
  "success": false,
  "error": "Unsupported file format",
  "details": "Only JPG, JPEG, PNG, GIF formats are supported",
  "code": "UNSUPPORTED_FORMAT"
}
```

#### 500 Internal Server Error
```json
{
  "success": false,
  "error": "Internal server error",
  "details": "Failed to process image. Detector error occurred.",
  "code": "DETECTOR_ERROR"
}
```

#### 503 Service Unavailable
```json
{
  "success": false,
  "error": "Service unavailable",
  "details": "Brick detector not initialized. Check model file.",
  "code": "DETECTOR_NOT_INITIALIZED"
}
```

---

## ⏱Performance Expectations

| Endpoint | Expected Response Time | Notes |
|----------|----------------------|-------|
| Health Check | < 100ms | Simple status check |
| Upload Image | < 3 seconds | Depends on image size |
| Analyze Photo | < 5 seconds | Includes full analysis |
| Inventory GET | < 500ms | With filters applied |
| Metadata Lookup | < 300ms | Brick/Set metadata |

---

## Versioning Strategy

- **Current Version**: v1.0
- **URL Pattern**: `/api/v{version}/` (e.g., `/api/v1/upload`)
- **Deprecation Policy**: Endpoints deprecated after 6 months
- **Breaking Changes**: Will increment major version (v2.0)
- **Version Header**: Optional `X-API-Version: 1.0`

---

## Changelog

### v1.0 (2024-01-15)
- Initial API release
- Basic brick detection via `/api/upload`
- Inventory management endpoints
- Set recommendations
- Brick and Set metadata endpoints
- Enhanced photo analysis via `/api/analyze-photo`

---

## Development Notes

### Testing the API
```bash
# Health check
curl http://localhost:5000/api/health

# Upload image
curl -X POST -F "file=@test_image.jpg" http://localhost:5000/api/upload

# Get inventory
curl http://localhost:5000/api/inventory

# Get brick metadata
curl http://localhost:5000/api/brick/3001
```

### Image Processing Notes
- Images are saved to `uploads/` directory
- Filenames include timestamp for uniqueness
- Base64 images must include data URL prefix
- Color detection uses HSV color space

---

## Agreement

This contract is agreed upon by:

**Backend Team**: NexGen Solutions  
**Signature**: Sidharth Nair  
**Date**: 12/4/2024

**Frontend Team**: NexGen Solutions  
**Signature**: Sidharth Nair  
**Date**: 12/4/2024

---

**Last Updated**: 12/4/2024  
**Next Review Date**: 01/15/2025

---

*This document serves as the single source of truth for API behavior. Any changes must be documented here before implementatio
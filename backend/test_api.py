#test_api.py
import unittest
import json
import os
import tempfile
from app import app

class TestLegoAPI(unittest.TestCase):
    
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True
        
        #Create a temporary test image
        self.test_image_path = tempfile.mktemp(suffix='.jpg')
        #Create a simple 10x10 black image
        import numpy as np
        import cv2
        img = np.zeros((10, 10, 3), dtype=np.uint8)
        cv2.imwrite(self.test_image_path, img)
    
    def tearDown(self):
        #Clean up test image
        if os.path.exists(self.test_image_path):
            os.remove(self.test_image_path)
    
    def test_health_check(self):
        """Test health check endpoint"""
        response = self.app.get('/api/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('status', data)
        self.assertIn('timestamp', data)
    
    def test_version_endpoint(self):
        """Test version endpoint"""
        response = self.app.get('/api/version')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('version', data)
        self.assertIn('endpoints', data)
    
    def test_upload_no_file(self):
        """Test upload without file"""
        response = self.app.post('/api/upload')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)
    
    def test_upload_invalid_file(self):
        """Test upload with invalid file type"""
        data = {'file': (open(self.test_image_path, 'rb'), 'test.txt')}
        response = self.app.post('/api/upload', data=data)
        self.assertEqual(response.status_code, 400)
    
    def test_analyze_photo_no_file(self):
        """Test analyze-photo without file"""
        response = self.app.post('/api/analyze-photo')
        self.assertEqual(response.status_code, 400)
    
    def test_get_brick_metadata_valid(self):
        """Test getting metadata for known brick"""
        response = self.app.get('/api/brick/3001')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertTrue(data['success'])
        self.assertIn('brick', data)
    
    def test_get_brick_metadata_invalid(self):
        """Test getting metadata for unknown brick"""
        response = self.app.get('/api/brick/9999')
        self.assertEqual(response.status_code, 404)
        data = json.loads(response.data)
        self.assertFalse(data['success'])
        self.assertIn('error', data)
    
    def test_inventory_get(self):
        """Test getting inventory"""
        response = self.app.get('/api/inventory')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertTrue(data['success'])
        self.assertIn('inventory', data)
    
    def test_inventory_post_invalid(self):
        """Test adding to inventory with invalid data"""
        response = self.app.post('/api/inventory', json={})
        self.assertEqual(response.status_code, 400)
    
    def test_recommendations_get(self):
        """Test getting recommendations"""
        response = self.app.get('/api/recommendations')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('recommendations', data)
    
    def test_error_handling(self):
        """Test error handling for invalid endpoints"""
        response = self.app.get('/api/nonexistent')
        self.assertEqual(response.status_code, 404)

if __name__ == '__main__':
    unittest.main()
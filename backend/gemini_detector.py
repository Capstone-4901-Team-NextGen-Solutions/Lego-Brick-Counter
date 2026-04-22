# backend/gemini_detector.py
import os
import base64
import json
import logging
import requests
from pathlib import Path

logger = logging.getLogger(__name__)


class GeminiDetector:
    """
    LEGO brick detector using Google Gemini Flash multimodal model.
    No training required — uses Gemini's general knowledge of LEGO bricks.
    """

    def __init__(self):
        self.api_key = os.getenv('GEMINI_API_KEY')
        self.api_base = 'https://generativelanguage.googleapis.com/v1beta/models'
        self.models_to_try = [
            'gemini-2.5-flash',
            'gemini-2.5-pro',
        ]
        self.loaded = self.api_key is not None
        if not self.loaded:
            logger.warning('[Gemini] GEMINI_API_KEY not set in .env')
        else:
            logger.info(f'[Gemini] Detector ready with {len(self.models_to_try)} fallback models')
            self.working_model = self._find_working_model()
            if self.working_model:
                logger.info(f'[Gemini] Ready with model: {self.working_model}')
            else:
                logger.warning('[Gemini] No working model found — check API key and billing')
                self.loaded = False

    def _find_working_model(self):
        """Test each model and return the first one that responds."""
        test_payload = {
            'contents': [{'parts': [{'text': 'Say OK'}]}],
            'generationConfig': {'maxOutputTokens': 5}
        }
        for model in self.models_to_try:
            try:
                url = f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={self.api_key}'
                r = requests.post(url, json=test_payload, timeout=10)
                if r.status_code == 200:
                    logger.info(f'[Gemini] Working model found: {model}')
                    return model
                else:
                    logger.warning(f'[Gemini] Model {model} returned {r.status_code}')
            except Exception as e:
                logger.warning(f'[Gemini] Model {model} error: {e}')
        return None

    def detect_bricks(self, image_path: str) -> list:
        """
        Detect LEGO bricks in an image using Gemini Flash.
        Returns list of dicts with brick_name, color, quantity, confidence.
        """
        if not self.loaded:
            raise RuntimeError('GEMINI_API_KEY not configured in .env')

        # Read and encode image as base64
        image_path = Path(image_path)
        if not image_path.exists():
            raise FileNotFoundError(f'Image not found: {image_path}')

        with open(image_path, 'rb') as f:
            image_data = base64.b64encode(f.read()).decode('utf-8')

        # Determine MIME type
        suffix = image_path.suffix.lower()
        mime_map = {'.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png'}
        mime_type = mime_map.get(suffix, 'image/jpeg')

        # Build request payload with response schema
        payload = {
            'contents': [
                {
                    'parts': [
                        {
                            'inline_data': {
                                'mime_type': mime_type,
                                'data': image_data
                            }
                        },
                        {
                            'text': (
                                'Identify all LEGO bricks in this image. '
                                'For each brick, provide: the type (e.g. Brick 2x4, Plate 1x2, Tile 2x2), '
                                'the color using standard LEGO color names '
                                '(e.g. Bright Red, Bright Blue, Bright Yellow, Black, White, '
                                'Dark Green, Bright Orange, Sand Blue, Dark Red, Reddish Brown, '
                                'Medium Stone Grey, Dark Stone Grey, Light Stone Grey, Brick Yellow, Nougat), '
                                'and the quantity of that specific brick type and color combination visible. '
                                'Return ONLY a JSON array. No explanation. No markdown.'
                            )
                        }
                    ]
                }
            ],
            'generationConfig': {
                'responseMimeType': 'application/json',
                'responseSchema': {
                    'type': 'ARRAY',
                    'items': {
                        'type': 'OBJECT',
                        'properties': {
                            'id':       {'type': 'STRING'},
                            'name':     {'type': 'STRING'},
                            'color':    {'type': 'STRING'},
                            'quantity': {'type': 'INTEGER'}
                        },
                        'required': ['id', 'name', 'color', 'quantity']
                    }
                }
            }
        }

        # Make API call with model fallback
        headers = {'Content-Type': 'application/json'}
        last_error = None

        models_to_attempt = []
        if self.working_model:
            models_to_attempt.append(self.working_model)
        models_to_attempt += [m for m in self.models_to_try if m != self.working_model]

        for model in models_to_attempt:
            try:
                url = f'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={self.api_key}'
                logger.info(f'[Gemini] Trying model: {model}')
                logger.info(f'[Gemini] Sending image to Gemini: {image_path.name}')
                response = requests.post(url, json=payload, headers=headers, timeout=30)

                if response.status_code == 429:
                    logger.warning(f'[Gemini] Quota exceeded for {model}, trying next model...')
                    last_error = f'Quota exceeded for {model}'
                    continue  # try next model

                if response.status_code != 200:
                    logger.error(f'[Gemini] API error {response.status_code} for {model}: {response.text}')
                    last_error = f'API error {response.status_code} for {model}: {response.text}'
                    continue  # try next model

                # Success — parse and return results
                logger.info(f'[Gemini] Success with model: {model}')
                response_json = response.json()

                try:
                    raw_text = response_json['candidates'][0]['content']['parts'][0]['text']
                    # Clean any accidental markdown fences
                    clean = raw_text.strip()
                    if clean.startswith('```'):
                        clean = clean.split('\n', 1)[-1]
                    if clean.endswith('```'):
                        clean = clean.rsplit('```', 1)[0]
                    bricks = json.loads(clean.strip())
                except (KeyError, IndexError, json.JSONDecodeError) as e:
                    logger.error(f'[Gemini] Failed to parse response from {model}: {e}')
                    logger.error(f'[Gemini] Raw response: {response_json}')
                    last_error = f'Failed to parse response from {model}: {e}'
                    continue  # try next model

                # Normalize to standard format
                results = []
                for brick in bricks:
                    results.append({
                        'brick_name': brick.get('name', 'Unknown'),
                        'color':      brick.get('color', 'Unknown'),
                        'count':      int(brick.get('quantity', 1)),
                        'confidence': 0.90,  # Gemini doesn't return confidence scores
                        'bounding_box': {}   # Gemini returns semantic results, not bbox
                    })

                logger.info(f'[Gemini] Detected {len(results)} brick types using {model}')
                return results

            except requests.exceptions.Timeout:
                logger.warning(f'[Gemini] Timeout for {model}, trying next...')
                last_error = f'Timeout for {model}'
                continue
            except Exception as e:
                logger.warning(f'[Gemini] Error for {model}: {e}, trying next...')
                last_error = str(e)
                continue

        # All models failed
        raise RuntimeError(f'All Gemini models failed. Last error: {last_error}')

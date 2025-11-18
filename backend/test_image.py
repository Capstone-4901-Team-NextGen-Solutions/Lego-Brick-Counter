#create_test_image.py
from PIL import Image
import os

#Create a test Lego-like image
img = Image.new('RGB', (400, 300), color=(222, 49, 49))  #Lego red
img.save('test_lego.jpg')
print("✅ test_lego.jpg created in:", os.path.abspath('test_lego.jpg'))
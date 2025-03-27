from flask import Flask, request, jsonify
import torch
from PIL import Image
import io
import numpy as np
import tensorflow as tf
import logging



app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Load the YOLOv5 model
model_yolo = torch.hub.load('ultralytics/yolov5', 'yolov5s', pretrained=True)

# Load the pretrained TensorFlow model
model_tf = tf.keras.models.load_model('traffic_light_cnn_model.h5')

# Class labels (adjust based on your training data)
class_labels = ['Green', 'Red', 'Yellow']

@app.route('/detect', methods=['POST'])
def detect_traffic_light():
    try:
        # Validate uploaded file
        file = request.files.get('image')
        if not file:
            return jsonify({"status": "failure", "message": "Error"}), 400
        if not file.filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            return jsonify({"status": "failure", "message": "Error"}), 400

        # Read and preprocess the image
        image_bytes = file.read()
        image = Image.open(io.BytesIO(image_bytes))

        # Perform detection using YOLO
        results = model_yolo(image)
        detected_objects = results.pandas().xyxy[0]
        traffic_lights = detected_objects[detected_objects['name'] == 'traffic light']

        if len(traffic_lights) > 0:
            xmin = int(traffic_lights['xmin'].values[0])
            ymin = int(traffic_lights['ymin'].values[0])
            xmax = int(traffic_lights['xmax'].values[0])
            ymax = int(traffic_lights['ymax'].values[0])

            # Crop the detected traffic light
            cropped_image = image.crop((xmin, ymin, xmax, ymax))

            # Classify the traffic light color
            color = classify_traffic_light_color(cropped_image)

            if color == "Unknown":
                return jsonify({"status": "failure", "message": "Error"}), 500

            return jsonify({"status": "success", "color": color}), 200
        else:
            return jsonify({"status": "failure", "message": "Error"}), 400
    except Exception as e:
        logging.error(f"Error: {e}")
        return jsonify({"status": "failure", "message": "Error"}), 500

def classify_traffic_light_color(cropped_image):
    try:
        # Preprocess the image for the TensorFlow model
        cropped_image = cropped_image.resize((64, 64))  # Resize to 64x64
        cropped_image = np.array(cropped_image) / 255.0  # Normalize pixel values
        cropped_image = np.expand_dims(cropped_image, axis=0)  # Add batch dimension

        # Make predictions
        predictions = model_tf.predict(cropped_image)
        predicted_class = np.argmax(predictions,axis=1)


        # Return the class label
        return class_labels[predicted_class[0]]
    except Exception as e:
        logging.error(f"Classification error: {e}")
        return "Unknown"

@app.route('/')
def home():
    return "Backend is running!"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
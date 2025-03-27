import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Traffic Light Detector',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TrafficLightDetector(),
    );
  }
}

class TrafficLightDetector extends StatefulWidget {
  @override
  _TrafficLightDetectorState createState() => _TrafficLightDetectorState();
}

class _TrafficLightDetectorState extends State<TrafficLightDetector> {
  CameraController? _cameraController;
  FlutterTts flutterTts = FlutterTts();
  String detectedColor = "No Detection";
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    initializeCamera();
    startDetection();
  }

  // Initialize the camera
  Future<void> initializeCamera() async {
    _cameraController = CameraController(cameras![0], ResolutionPreset.medium);
    await _cameraController?.initialize();
    setState(() {});
  }

  // Start detecting traffic lights at regular intervals
  void startDetection() {
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      detectTrafficLight();
    });
  }

  // Detect the traffic light color
Future<void> detectTrafficLight() async {
  try {
    final image = await _cameraController?.takePicture();
    if (image == null) return;

    // Replace with your API URL (backend server)
    const apiUrl = "http://192.168.43.4:5000/detect";  // This is your Flask API endpoint.

    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.files.add(await http.MultipartFile.fromPath('image', image.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var result = json.decode(responseData);
      setState(() {
        detectedColor = result['color'];  // Assuming the API returns a 'color' field
      });
      await flutterTts.speak("The traffic light is $detectedColor");
    } else {
      setState(() {
        detectedColor = "Detection Failed";
      });
    }
  } catch (e) {
    print(e);
    setState(() {
      detectedColor = "Error occurred";
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Traffic Light Detector')),
      body: Column(
        children: [
          Expanded(
            child: _cameraController?.value.isInitialized ?? false
                ? CameraPreview(_cameraController!)
                : Center(child: CircularProgressIndicator()),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Detected Color: $detectedColor",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _timer.cancel();
    super.dispose();
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Camera and Location',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SignUpScreen(),
    );
  }
}

class SignUpScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NextPage(),
              ),
            );
          },
          child: Text('Go to Camera and Location Page'),
        ),
      ),
    );
  }
}

class NextPage extends StatefulWidget {
  @override
  _NextPageState createState() => _NextPageState();
}

class _NextPageState extends State<NextPage> {
  late CameraController _controller;
  late List<CameraDescription> _cameras;
  String location = 'Fetching location...';
  String address = '';
  File? capturedImage; // To store the captured image

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _fetchLocation();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    _controller = CameraController(_cameras[0], ResolutionPreset.medium);

    await _controller.initialize();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _fetchLocation() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);

        Placemark place = placemarks[0];
        address =
        '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}';
        location =
        'Lat: ${position.latitude}, Long: ${position.longitude}';
      } catch (e) {
        location = 'Error fetching location: $e';
      }
    } else {
      location = 'Location permission denied.';
    }

    if (mounted) {
      setState(() {});
    }
  }
  Future<void> _captureImage() async {
    try {
      final XFile file = await _controller.takePicture();
      capturedImage = File(file.path);

      // Read the image file as bytes
      final Uint8List imageBytes = capturedImage!.readAsBytesSync();

      // Get the temporary directory
      final tempDir = await getTemporaryDirectory();

      // Create a temporary file to save the modified image with added location information
      final tempImagePath = '${tempDir.path}/output_image.png';

      // Open the temporary file for image processing
      final recorder = ui.PictureRecorder();
      final paint = Paint()..color = Colors.red;
      final canvas = Canvas(recorder);

      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final img = frameInfo.image;
      canvas.drawImage(img, Offset.zero, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Location: $location\nAddress: $address',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(10, img.height - 60));

      // Save the modified image with added text to the temporary file
      final tempImage = File(tempImagePath);
      final imgBytes = await recorder
          .endRecording()
          .toImage(img.width, img.height)
          .then((img) => img.toByteData(format: ui.ImageByteFormat.png))
          .then((byteData) => byteData!.buffer.asUint8List());
      await tempImage.writeAsBytes(imgBytes);

      setState(() {
        capturedImage = tempImage; // Update capturedImage with the temporary file
      });
    } catch (e) {
      print('Error capturing image: $e');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera and Location Page'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: capturedImage != null
                ? Image.file(capturedImage!)
                : _controller.value.isInitialized
                ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: CameraPreview(_controller),
            )
                : Center(
              child: CircularProgressIndicator(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Location: $location\nAddress: $address',
              style: TextStyle(fontSize: 16.0),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              _captureImage(); // Capture and process the image
            },
            child: Text('Capture'),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}